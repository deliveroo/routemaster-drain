# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'routemaster/drain'

Gem::Specification.new do |spec|
  spec.name          = 'routemaster-drain'
  spec.version       = Routemaster::Drain::VERSION
  spec.authors       = ['Julien Letessier']
  spec.email         = ['julien.letessier@gmail.com']
  spec.summary       = %q{Event receiver for the Routemaster bus}
  spec.homepage      = 'http://github.com/deliveroo/routemaster-drain'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = %w(lib)

  spec.add_runtime_dependency     'addressable'
  spec.add_runtime_dependency     'faraday', '>= 1.8.0', '< 1.9.0'
  spec.add_runtime_dependency     'faraday_middleware'
  spec.add_runtime_dependency     'typhoeus', '~> 1.1'
  spec.add_runtime_dependency     'rack', '>= 1.4.5'
  spec.add_runtime_dependency     'wisper', '~> 1.6.1'
  spec.add_runtime_dependency     'hashie'
  spec.add_runtime_dependency     'redis-namespace'
  spec.add_runtime_dependency     'concurrent-ruby'
  spec.add_runtime_dependency     'circuitbox'
  spec.add_runtime_dependency     'moneta', '1.0.0'
end
