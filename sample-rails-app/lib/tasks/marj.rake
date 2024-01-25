# frozen_string_literal: true

require 'English'
namespace :marj do
  desc 'Test Marj'
  task test: :environment do
    loaded = false
    ActiveSupport.on_load(:active_record) { loaded = true }
    raise 'ActiveRecord loaded too soon' if loaded

    Marj.count
    raise 'ActiveRecord not loaded' unless loaded

    MarjRecord.delete_all
    raise 'Unexpected job found' unless Marj.count.zero?

    TestJob.perform_later('TestJob.runs << 1')
    raise 'Job not enqueued' unless Marj.count == 1

    Marj.first.perform_now
    raise 'Job not executed' unless TestJob.runs == [1]
    raise 'Job not deleted' unless Marj.count.zero?

    TestJob.perform_later('raise "hi"')
    raise 'Job not enqueued' unless Marj.first&.executions = 0

    Marj.first.perform_now
    raise 'Job not executed' unless (Marj.first.executions = 1)

    Marj.first.perform_now rescue e = $ERROR_INFO
    raise 'error not raised' unless e&.message == 'hi'
    raise 'Job not deleted' unless Marj.count.zero?
  end
end
