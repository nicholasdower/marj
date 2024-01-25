#!/usr/bin/env ruby
# frozen_string_literal: true

require 'English'
require 'active_job'
require 'active_job/base'
require 'active_record'
require 'marj'
require 'sqlite3'

ActiveJob::Base.queue_adapter = :marj
Time.zone = 'UTC'

class CreateJobs < ActiveRecord::Migration[7.1]
  def self.up
    create_table :jobs, id: :string, primary_key: :job_id do |table|
      table.string   :job_class,            null: false
      table.text     :arguments,            null: false
      table.string   :queue_name,           null: false
      table.integer  :priority
      table.integer  :executions,           null: false
      table.text     :exception_executions, null: false
      table.datetime :enqueued_at,          null: false
      table.datetime :scheduled_at
      table.string   :locale,               null: false
      table.string   :timezone,             null: false
    end

    add_index :jobs, %i[enqueued_at]
    add_index :jobs, %i[scheduled_at]
    add_index :jobs, %i[priority scheduled_at enqueued_at]
  end

  def self.down
    drop_table :jobs
  end
end

Dir.glob('storage/**/*').each { |file| File.delete(file) }
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: 'storage/test.db')
ActiveRecord::Base.connection.drop_table(:jobs) if ActiveRecord::Base.connection.table_exists?(:jobs)
CreateJobs.migrate(:up)

MarjRecord.delete_all
raise 'Unexpected job found' unless Marj.count.zero?

class TestJob < ActiveJob::Base
  retry_on Exception, wait: 10.seconds, attempts: 2

  @runs = []

  class << self
    attr_reader :runs
  end

  def perform(*args)
    args.map { eval(_1) } # rubocop:disable Security/Eval
  end
end

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
