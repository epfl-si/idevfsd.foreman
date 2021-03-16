# coding: utf-8
# Monkey-patch Foreman so that the “Reboot now” button kexec's when possible

require 'timeout'
require 'socket'

module IDEVFSD
  PING_TIMEOUT = 2
  SSH_TIMEOUT = 20

  class KexecableHost
    def initialize(host)
      @host = host
    end

    delegate_missing_to :@host

    # View templates use @host as a string to build URLs etc. (and for
    # whatever reason, when it comes to to_s, delegate_missing_to
    # doesn't)
    def to_s
      @host.to_s
    end

    # We never have “errors that may prevent whatever”
    def build_status_checker
      ItsOkayHostBuildStatus.new(@host.build_status_checker)
    end

    # We do support power...
    def supports_power_and_running?
      true
    end

    # ... albeit in our own kind of way
    def power
      KexecablePower.new(@host)
    end
  end

  class ItsOkayHostBuildStatus
    def initialize(status)
      @status = status
    end

    delegate_missing_to :@status

    def state
      true
    end
  end

  class KexecablePower
    def initialize(host)
      @service = KexecService.new(host)
    end

    def reset
      @service.kexec!
    end
  end

  class KexecService
    def initialize(host)
      @host = host
    end
    def api_url
      "https://#{@host.ip}:8443"
    end

    def kexec_method
      if ! ping?
        return nil  # For speed
      elsif can_discovery_api?
        return :discovery_api
      elsif can_ssh?
        return :ssh
      else
        return nil
      end
    end

    def kexec!
      case kexec_method
      when :discovery_api
        kexec_discovery_api!
      when :ssh
        kexec_ssh!
      when nil
        raise "No way to tell #{@host.name} to kexec the installer at this time"
      else
        raise "Unknown kexec_method #{kexec_method}"
      end
    end

    def wrapped_host
      @host.is_a?(KexecableHost) ? @host : KexecableHost::new(@host)
    end

    def self.wrap_if_kexecable(host)
      this = self.new(host)
      this.kexec_method.nil? ? host : this.wrapped_host
    end

    private

    def ping?
      begin
        Timeout.timeout(PING_TIMEOUT) do
          s = TCPSocket.new(@host.ip, 8443)
          s.close
          return true
        end
      rescue Errno::ECONNREFUSED
        return true
      rescue Timeout::Error, Errno::ENETUNREACH, Errno::EHOSTUNREACH
        return false
      end
    end

    def can_discovery_api?
      inventory_api = ::ForemanDiscovery::NodeAPI::Inventory.new(:url => api_url)
      begin
        inventory_api.facter.include? "discovery_version"
        true
      rescue => e
        Rails.logger.error e
        false
      end
    end

    def can_ssh?
      begin
        dummy_command = KexecSshService.new(@host, "true").wait
        if dummy_command["result"] == "success"
          true
        else
          Rails.logger.error dummy_command
          false
        end
      rescue => e
        Rails.logger.error "can_ssh?"
        Rails.logger.error e
        false
      end
    end

    def kexec_discovery_api!
      template = @host.provisioning_template(:kind => 'kexec')
      json = template.render(host: @host)
      ::ForemanDiscovery::NodeAPI::Power.service(:url => api_url).kexec(json)
    end

    def kexec_ssh!
      KexecSshService.new(@host, "/usr/local/sbin/foreman-reinstall #{@host.token.value}")
    end

    def start_ssh_task
      dynflow.foo
    end

    class KexecSshService
      def initialize(host, command)
        smart_proxy = best_ssh_smart_proxy_for(host)
        @dynflow = ProxyAPI::ForemanDynflow::DynflowProxy.new(:url => smart_proxy.url)
        # https://github.com/theforeman/smart_proxy_remote_execution_ssh#usage
        action_input = {
            "task_id" => "ssh #{host.name} #{command}",
            "script" => "#{command}",
            "hostname" => "#{host.name}"
          }
        @task = @dynflow.trigger_task(
          "ForemanRemoteExecutionCore::Actions::RunScript",
          action_input)
      end

      def wait(timeout = SSH_TIMEOUT)
        begin
          Timeout.timeout(timeout) do
            while true do
              stat = status
              return stat if stat["result"] != "pending"
              sleep 1
            end
          end
        rescue Timeout::Error
          Rails.logger.error status
        end
      end

      def status
        @dynflow.status_of_task(@task["task_id"])
      end

      private

      def best_ssh_smart_proxy_for(host)
        proxies = host.remote_execution_proxies(:SSH)
        for key in [:subnet, :fallback, :global] do
          values = proxies[key]
          if values.respond_to?(:first)
            if ! values.first.nil?
              return values.first
            end
          elsif ! values.nil?
            return values
          end
        end
        raise "Cannot find suitable smart proxy for ssh to #{host}"
      end
    end
  end

  module HostsControllerExtensions
    extend ActiveSupport::Concern

    included do
      before_action :wrap_host_if_kexecable,  :only => [:review_before_build, :setBuild]
      before_action :wrap_hosts_if_kexecable, :only => [:submit_multiple_build]
    end

    def wrap_host_if_kexecable
      @host = KexecService::wrap_if_kexecable @host
    end

    def wrap_hosts_if_kexecable
      @hosts = @hosts.map { |h| KexecService::wrap_if_kexecable h }
    end
  end

  class Engine < ::Rails::Engine
    config.to_prepare do
      ::HostsController.send :include, HostsControllerExtensions
    end
  end
end
