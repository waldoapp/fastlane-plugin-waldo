# coding: utf-8

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/waldo/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-waldo'
  spec.version       = Fastlane::Waldo::VERSION
  spec.author        = %q{J. G. Pusey}
  spec.email         = %q{john@waldo.io}

  spec.summary       = %q{Upload build to Waldo}
  spec.homepage      = "https://github.com/waldoapp/fastlane-plugin-waldo"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'fastlane'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec'
end
