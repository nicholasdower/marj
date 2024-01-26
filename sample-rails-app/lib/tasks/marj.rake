# frozen_string_literal: true

require 'English'
namespace :marj do
  desc 'Test Marj'
  task test: :environment do
    loaded = false
    ActiveSupport.on_load(:active_record) { loaded = true }
    raise 'ActiveRecord loaded too soon' if loaded

    Marj::Jobs.count
    raise 'ActiveRecord not loaded' unless loaded

    Marj::Record.delete_all
    raise 'Unexpected job found' unless Marj::Jobs.count.zero?

    TestJob.perform_later('TestJob.runs << 1')
    raise 'Job not enqueued' unless Marj::Jobs.count == 1

    Marj::Jobs.first.perform_now
    raise 'Job not executed' unless TestJob.runs == [1]
    raise 'Job not deleted' unless Marj::Jobs.count.zero?

    TestJob.perform_later('raise "hi"')
    raise 'Job not enqueued' unless Marj::Jobs.first&.executions = 0

    Marj::Jobs.first.perform_now
    raise 'Job not executed' unless (Marj::Jobs.first.executions = 1)

    Marj::Jobs.first.perform_now rescue e = $ERROR_INFO
    raise 'error not raised' unless e&.message == 'hi'
    raise 'Job not deleted' unless Marj::Jobs.count.zero?
  end
end
