#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
ENV['LEVEL'] ||= Logger::INFO.to_s

require 'fileutils'
require 'irb'
require 'awesome_print'
require_relative 'init'

def reload
  Dir.glob('lib/**/*.rb').each { |f| load "./#{f}" }
end

def level(level)
  level = Integer(level) if %w[0 1 2 3 4 5].include?(level)

  ActiveRecord::Base.logger.level = level if level
  ActiveJob::Base.logger.level = level if level
  ActiveJob::Base.logger.level
end

FileUtils.touch('.irb_history')
IRB.conf[:HISTORY_FILE] = '.irb_history'

FileUtils.touch('.irb')

begin
  TestDb.reset
  IRB.start
ensure
  TestDb.destroy
end
