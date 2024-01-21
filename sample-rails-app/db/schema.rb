# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 20_240_121_104_547) do
  create_table 'jobs', primary_key: 'job_id', id: :string, force: :cascade do |t|
    t.string 'job_class', null: false
    t.text 'arguments', null: false
    t.string 'queue_name', null: false
    t.integer 'priority'
    t.integer 'executions', null: false
    t.text 'exception_executions', null: false
    t.datetime 'enqueued_at', null: false
    t.datetime 'scheduled_at'
    t.string 'locale', null: false
    t.string 'timezone', null: false
    t.index ['enqueued_at'], name: 'index_jobs_on_enqueued_at'
    t.index %w[priority scheduled_at enqueued_at], name: 'index_jobs_on_priority_and_scheduled_at_and_enqueued_at'
    t.index ['scheduled_at'], name: 'index_jobs_on_scheduled_at'
  end
end
