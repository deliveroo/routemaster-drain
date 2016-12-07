require 'routemaster/jobs/backends/resque'
require 'spec/routemaster/jobs/backends/backend_examples'

RSpec.describe Routemaster::Jobs::Backends::Resque do
  around do |example|
    original_inline = Resque.inline
    begin
      Resque.inline = true
      example.run
    ensure
      Resque.inline = original_inline
    end
  end

  it_behaves_like 'a job backend'
end
