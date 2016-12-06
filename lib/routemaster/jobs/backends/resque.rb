require 'resque'
require 'routemaster/jobs/job'

module Routemaster
  module Jobs
    module Backends
      class Resque
        def initialize(adapter = nil)
          @adapter = adapter || ::Resque
        end

        def enqueue(queue, job_class, *args)
          job_data = data_for(job_class, args)
          @adapter.enqueue_to(queue, JobWrapper, job_data)
        end

        class JobWrapper
          def self.perform(job_data)
            Job.execute(job_data)
          end
        end
      end
    end
  end
end
