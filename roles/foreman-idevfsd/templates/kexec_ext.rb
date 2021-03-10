# coding: utf-8
# Monkey-patch Foreman so that the “Reboot now” button kexec's when possible

module IDEVFSD
  class KexecableHost
    def initialize(host)
      @host = host
    end

    delegate_missing_to :@host

    # We want to render templates using this object as @host
    class Jail < ::Host::Managed::Jail
    end

    # Templates use @host as a string to build URLs etc. (and for
    # whatever reason, when it comes to to_s, delegate_missing_to
    # doesn't)
    def to_s
      @host.to_s
    end

    # Fill in discovery facts as if this were a discovered host.
    # This is necessary for the default kexec template to do its
    # job.
    def facts
      facts = @host.facts
      facts['discovery_bootif'] = @host.mac
      facts['discovery_ip'] = @host.ip
      facts['discovery_netmask'] = @host.subnet.mask
      facts['discovery_gateway'] = @host.subnet.gateway
      facts['discovery_dns'] = @host.subnet.dns_primary
      facts
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

    def ping?
      inventory_api = ::ForemanDiscovery::NodeAPI::Inventory.new(:url => api_url)
      begin
        inventory_api.facter.include? "discovery_version"
      rescue
        false
      end
    end

    def kexec!
      json = @host.provisioning_template(:kind => 'kexec').render(host: wrapped_host)
      ::ForemanDiscovery::NodeAPI::Power.service(:url => api_url).kexec(json)
    end

    def wrapped_host
      @host.facts['discovery_ip'].nil? ? KexecableHost::new(@host) : @host
    end

    def self.wrap_if_kexecable(host)
      this = self.new(host)
      this.ping? ? this.wrapped_host : host
    end
  end

  module HostsControllerExtensions
    extend ActiveSupport::Concern

    included do
      before_action :wrap_host_if_kexecable, :only => [:review_before_build, :setBuild]
    end

    def wrap_host_if_kexecable
      @host = KexecService::wrap_if_kexecable @host
    end
  end

  class Engine < ::Rails::Engine
    config.to_prepare do
      ::HostsController.send :include, HostsControllerExtensions
    end
  end
end
