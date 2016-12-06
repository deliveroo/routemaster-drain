require 'sidekiq'
require 'routemaster/jobs/job'

module Routemaster
  module Jobs
    module Backends
      class Sidekiq
        def initialize(adapter = nil)
          @adapter = adapter || ::Sidekiq::Client
        end

        def enqueue(queue, job_class, *args)
          job_data = Job.data_for(job_class, args)
          @adapter.push('queue' => queue, 'class' => JobWrapper, 'args' => [job_data])
        end

        class JobWrapper
          include ::Sidekiq::Worker

          def perform(job_data)
            Job.execute(job_data)
          end
        end
      end
    end
  end
end
