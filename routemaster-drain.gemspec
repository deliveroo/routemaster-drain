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
  spec.homepage      = 'http://github.com/HouseTrip/routemaster_drain'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = %w(lib)

  spec.add_runtime_dependency     'faraday', '>= 0.9.0'
  spec.add_runtime_dependency     'faraday_middleware'
  spec.add_runtime_dependency     'net-http-persistent', '< 3' # 3.x is currently incompatible with faraday
  spec.add_runtime_dependency     'rack', '>= 1.4.5'
  spec.add_runtime_dependency     'wisper', '~> 1.6.1'
  spec.add_runtime_dependency     'hashie'
  spec.add_runtime_dependency     'redis-namespace'
  spec.add_runtime_dependency     'thread'
end
