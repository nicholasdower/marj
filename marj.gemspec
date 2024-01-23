# frozen_string_literal: true

version = File.read('app/models/marj.rb').match(/VERSION = '([^']*)'/)[1]

Gem::Specification.new do |spec|
  spec.name          = 'marj'
  spec.description   = 'A minimal, database-backed queueing backend for ActiveJob.'
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/nicholasdower/marj'
  spec.version       = version
  spec.license       = 'MIT'
  spec.authors       = ['Nick Dower']
  spec.email         = 'nicholasdower@gmail.com'

  spec.metadata      = {
    'bug_tracker_uri' => 'https://github.com/nicholasdower/marj/issues',
    'changelog_uri' => "https://github.com/nicholasdower/marj/releases/tag/v#{version}",
    'documentation_uri' => "https://www.rubydoc.info/github/nicholasdower/marj/v#{version}",
    'homepage_uri' => 'https://github.com/nicholasdower/marj',
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/nicholasdower/marj'
  }
  spec.required_ruby_version = '>= 2.7.0'

  spec.files = Dir['lib/**/*'] + Dir['app/**/*'] + %w[README.md LICENSE.txt]

  spec.add_runtime_dependency 'activejob', '>=  7.1'
  spec.add_runtime_dependency 'activerecord', '>=  7.1'
end
