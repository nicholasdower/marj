# frozen_string_literal: true

version = '6.1.0'

Gem::Specification.new do |spec|
  spec.name          = 'marj'
  spec.description   = 'Marj (Minimal ActiveRecord Jobs) is a minimal database-backed ActiveJob queueing backend.'
  spec.summary       = 'Minimal ActiveRecord Jobs'
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

  spec.files = Dir['lib/**/*'] + %w[README.md LICENSE.txt]

  spec.add_dependency 'activejob', '>=  7.1'
  spec.add_dependency 'activerecord', '>=  7.1'
end
