require 'sidekiq/testing'
require 'routemaster/jobs/backends/sidekiq'
require 'spec/routemaster/jobs/backends/backend_examples'

RSpec.describe Routemaster::Jobs::Backends::Sidekiq do
  around do |example|
    Sidekiq::Testing.inline! { example.run }
  end

  it_behaves_like 'a job backend'
end
