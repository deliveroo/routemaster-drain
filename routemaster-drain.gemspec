# coding: utf-8
lib = File.expand_path('..', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'routemaster/client/version'

Gem::Specification.new do |spec|
  spec.name          = 'routemaster-drain'
  spec.version       = Routemaster::Client::VERSION
  spec.authors       = ['Julien Letessier']
  spec.email         = ['julien.letessier@gmail.com']
  spec.summary       = %q{Event receiver for the Routemaster bus}
  spec.homepage      = 'http://github.com/HouseTrip/routemaster_drain'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = %w(.)

  spec.add_runtime_dependency     'faraday'
  spec.add_runtime_dependency     'typhoeus'
  spec.add_runtime_dependency     'rack'
  spec.add_runtime_dependency     'wisper'
  spec.add_runtime_dependency     'hashie'
  spec.add_runtime_dependency     'redis-namespace'
end
