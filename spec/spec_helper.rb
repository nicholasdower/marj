# frozen_string_literal: true

if ENV['COVERAGE'] == '1'
  require 'simplecov'
  require 'simplecov-console'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::Console]
  )

  SimpleCov.start do
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
    add_filter %w[script/ spec/]
  end
end

require 'logger'
require 'timecop'

ENV['LEVEL'] ||= Logger::FATAL.to_s

require_relative '../script/init'

RSpec.configure do |config|
  config.before(:suite) do
    TestDb.reset
  end

  config.after(:suite) do
    TestDb.destroy
  end

  config.before do
    TestDb.clear
    Timecop.freeze
  end

  config.after do
    Timecop.return
    TestJob.reset
  end
end
