require 'sidekiq'

module Routemaster
  module Jobs
    module Backends
      class Sidekiq
        def initialize(adapter = nil)
          @adapter = adapter || ::Sidekiq::Client
        end

        def enqueue(queue, job_class, *args)
          @adapter.push('queue' => queue, 'class' => job_class, 'args' => args)
        end
      end
    end
  end
end
