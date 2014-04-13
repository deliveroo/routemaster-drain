# coding: utf-8
lib = File.expand_path('..', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'routemaster/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'routemaster-client'
  spec.version       = Routemaster::Client::VERSION
  spec.authors       = ['Julien Letessier']
  spec.email         = ['julien.letessier@gmail.com']
  spec.summary       = %q{Client API for the Routemaster event bus}
  spec.homepage      = 'http://github.com/HouseTrip/routemaster_client'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = %w(.)

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'pry-nav'
  spec.add_development_dependency 'rack-test'

  spec.add_runtime_dependency     'faraday'
  spec.add_runtime_dependency     'net-http-persistent'
  spec.add_runtime_dependency     'sinatra'
end
