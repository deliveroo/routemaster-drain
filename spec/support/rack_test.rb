ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'

class ErrorRackApp
  def call(env)
    [501, {}, 'fake app']
  end
end


RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

