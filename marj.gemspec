# frozen_string_literal: true

require_relative 'lib/marj/version'

Gem::Specification.new do |spec|
  spec.name          = 'marj'
  spec.description   = 'Minimal Active Record Job'
  spec.summary       = 'An ActiveJob queuing backend.'
  spec.homepage      = 'https://github.com/nicholasdower/marj'
  spec.version       = Marj::VERSION
  spec.license       = 'MIT'
  spec.authors       = ['Nick Dower']
  spec.email         = 'nicholasdower@gmail.com'

  spec.metadata      = {
    'bug_tracker_uri' => 'https://github.com/nicholasdower/marj/issues',
    'changelog_uri' => "https://github.com/nicholasdower/marj/releases/tag/v#{Marj::VERSION}",
    'documentation_uri' => "https://www.rubydoc.info/github/nicholasdower/marj/v#{Marj::VERSION}",
    'homepage_uri' => 'https://github.com/nicholasdower/marj',
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/nicholasdower/marj'
  }
  spec.required_ruby_version = '>= 2.7.0'

  spec.files = Dir['lib/**/*']

  spec.add_runtime_dependency 'activejob', '>=  7.1'
  spec.add_runtime_dependency 'activerecord', '>=  7.1'
end
