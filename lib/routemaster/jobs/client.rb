require 'routemaster/config'

module Routemaster
  module Jobs
    class Client
      extend Forwardable

      def_delegators :@backend, :enqueue

      def initialize(adapter = nil)
        @backend = build_backend(adapter)
      end

      private

      def build_backend(adapter)
        case Config.queue_adapter
        when :resque
          require 'routemaster/jobs/backends/resque'
          Backends::Resque.new(adapter)
        when :sidekiq
          require 'routemaster/jobs/backends/sidekiq'
          Backends::Sidekiq.new(adapter)
        else
          raise "Unsupported queue adapter '#{Config.queue_adapter}"
        end
      end
    end
  end
end
