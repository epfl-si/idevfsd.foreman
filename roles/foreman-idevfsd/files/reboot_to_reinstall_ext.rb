# coding: utf-8
#
# Monkey-patch Foreman so that the “Reboot now” button works, despite
# the lack of BMC in VMs.
#
# Two different mechanisms are made available for this feature:
#
# - the discovery image's kexec API (the one that the “auto-provision“
#   feature uses, except that in our case, we want to activate it
#   from a “real” host, not a discovered host);
#
# - ssh'ing into the already-installed node to run the
#   `/usr/local/sbin/foreman-reinstall` script (which may or may not
#   wind up invoking kexec(8) as well)

require 'timeout'
require 'socket'

module IDEVFSD
  PING_TIMEOUT = 2
  SSH_TIMEOUT = 20

  class ReinstallableHost
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
      ReinstallablePower.new(@host)
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

  class ReinstallablePower
    def initialize(host)
      @service = RebootToReinstallService.new(host)
    end

    def reset
      @service.reinstall!
    end
  end

  class RebootToReinstallService
    def initialize(host)
      @host = host
    end
    def api_url
      "https://#{@host.ip}:8443"
    end

    def reinstall_method
      begin
        Timeout.timeout(PING_TIMEOUT) do
          return :discovery_api if can_reinstall_via_discovery_api?
        end
      rescue Errno::ECONNREFUSED
        # Host is live, but port 8443 is closed. Carry on
      rescue Timeout::Error, Errno::ENETUNREACH, Errno::EHOSTUNREACH
        # Host is powered off or misconfigured from a network
        # standpoint. Short-circuit the probe for speed
        return nil
      end

      return :ssh if can_reinstall_via_ssh?

      return nil
    end

    def reinstall!
      case reinstall_method
      when :discovery_api
        reinstall_via_discovery_api!
      when :ssh
        reinstall_via_ssh!
      when nil
        raise "No way to tell #{@host.name} to run the installer at this time"
      else
        raise "Unknown reinstall_method #{reinstall_method}"
      end
    end

    def wrapped_host
      @host.is_a?(ReinstallableHost) ? @host : ReinstallableHost::new(@host)
    end

    def self.wrap_if_reinstallable(host)
      this = self.new(host)
      this.reinstall_method.nil? ? host : this.wrapped_host
    end

    private

    def foreman_reinstall_script_path
      "/usr/local/sbin/foreman-reinstall"
    end

    def can_reinstall_via_discovery_api?
      inventory_api = ::ForemanDiscovery::NodeAPI::Inventory.new(:url => api_url)
      inventory_api.facter.include? "discovery_version"
    end

    def can_reinstall_via_ssh?
      begin
        ls_status = SshService.new(@host, "ls -l #{foreman_reinstall_script_path}").wait
        if ls_status["result"] == "success"
          true
        else
          Rails.logger.error "can_reinstall_via_ssh? -> #{ls_status}"
          false
        end
      rescue => e
        Rails.logger.error e
        false
      end
    end

    def reinstall_via_discovery_api!
      template = @host.provisioning_template(:kind => 'kexec')
      json = template.render(host: @host)
      ::ForemanDiscovery::NodeAPI::Power.service(:url => api_url).kexec(json)
    end

    def reinstall_via_ssh!
      SshService.new(@host, "#{foreman_reinstall_script_path} #{@host.token.value}")
    end

    class SshService
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
          stat
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
      before_action :wrap_host_if_reinstallable,  :only => [:review_before_build, :setBuild]
      before_action :wrap_hosts_if_reinstallable, :only => [:submit_multiple_build]
    end

    def wrap_host_if_reinstallable
      @host = RebootToReinstallService::wrap_if_reinstallable @host
    end

    def wrap_hosts_if_reinstallable
      @hosts = @hosts.map { |h| RebootToReinstallService::wrap_if_reinstallable h }
    end
  end

  class Engine < ::Rails::Engine
    config.to_prepare do
      ::HostsController.send :include, HostsControllerExtensions
    end
  end
end
