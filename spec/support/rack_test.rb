ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'

class ErrorRackApp
  attr_reader :last_env

  def initialize
    @last_env = {}
  end

  def call(env)
    @last_env = env
    [501, {}, 'fake app']
  end
end


RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

