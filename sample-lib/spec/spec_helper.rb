# frozen_string_literal: true

require 'English'
require 'active_job'
require 'active_job/base'
require 'active_record'
require 'marj'
require 'sqlite3'

require_relative '../lib/test_job'

ActiveRecord::Base.logger = Logger.new($stdout, level: Logger::FATAL)
ActiveJob::Base.logger = Logger.new($stdout, level: Logger::FATAL)
ActiveRecord::Migration.verbose = false

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
