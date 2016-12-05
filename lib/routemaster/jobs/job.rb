module Routemaster
  module Jobs
    class Job
      class << self
        def execute(job_data)
          job = create_job(job_data)
          job.perform(*job_data['args'])
        end

        private

        def create_job(job_data)
          job_class = job_data['class']
          Kernel.const_get(job_class)
        end
      end
    end
  end
end
