require 'resque'

module Routemaster
  module Jobs
    module Backends
      class Resque
        def initialize(adapter = nil)
          @adapter = adapter || ::Resque
        end

        def enqueue(queue, job_class, *args)
          @adapter.enqueue_to(queue, job_class, *args)
        end
      end
    end
  end
end
