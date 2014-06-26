# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'transit/version'

Gem::Specification.new do |spec|
  spec.name          = "transit-ruby"
  spec.version       = Transit::VERSION
  spec.authors       = ["Russ Olsen","David Chelimsky"]
  spec.email         = ["russ@cognitect.com", "dchelimsky@cognitect.com"]
  spec.summary       = %q{Transit marshalling for Ruby}
  spec.description   = %q{Transit marshalling for Ruby}
  spec.homepage      = "http://github.com/cognitect/transit-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^spec/})
  spec.require_paths = ["lib"]

  spec.add_dependency "addressable",       "~> 2.3.6"
  spec.add_dependency "msgpack",           "~> 0.5.8"
  spec.add_dependency "oj",                "~> 2.9.8"
  spec.add_development_dependency "rake",  "~> 10.1.1"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "wrong", "~> 0.7.1"
end
