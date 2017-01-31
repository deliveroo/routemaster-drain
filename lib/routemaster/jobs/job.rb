require 'routemaster/jobs'

module Routemaster
  module Jobs
    class Job
      class << self
        def data_for(job_class, args)
          { 'class' => job_class.to_s, 'args'  => args }
        end

        def execute(job_data)
          job = create_job(job_data)
          job.new.perform(*job_data['args'])
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
