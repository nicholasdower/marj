# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Custom Record' do
  before do
    stub_const('CreateMyJobs', Class.new(ActiveRecord::Migration[7.1]))
    CreateMyJobs.class_eval do
      def self.up
        create_table :my_jobs, id: :string, primary_key: :job_id do |table|
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
      end

      def self.down
        drop_table :my_jobs
      end
    end

    stub_const('MyRecord', Class.new(Marj::Record))
    MyRecord.table_name = 'my_jobs'

    CreateMyJobs.migrate(:up)

    stub_const('MyApplicationJob', Class.new(ActiveJob::Base))
    MyApplicationJob.class_eval do
      self.queue_adapter = MarjAdapter.new(MyRecord)

      extend Marj::JobsInterface

      def self.all
        Marj::Relation.new(self == MyApplicationJob ? MyRecord.ordered : MyRecord.where(job_class: self).ordered)
      end

      @runs = []

      self.class.attr_reader :runs, :log

      def perform(*args)
        args.map { eval(_1) } # rubocop:disable Security/Eval
      end
    end

    stub_const('MyJob', Class.new(MyApplicationJob))
    stub_const('MyOtherJob', Class.new(MyApplicationJob))
  end

  after do
    CreateMyJobs.migrate(:down)
  end

  it 'inserts records' do
    expect { MyJob.perform_later }.to change(MyRecord, :count).from(0).to(1)
  end

  it 'queries jobs' do
    my_job = MyJob.perform_later
    Timecop.travel(1.minute)
    my_other_job = MyOtherJob.perform_later
    Timecop.travel(1.minute)
    expect(MyApplicationJob.next.job_id).to eq(my_job.job_id)
    expect(MyJob.next.job_id).to eq(my_job.job_id)
    expect(MyOtherJob.next.job_id).to eq(my_other_job.job_id)
  end

  it 'runs jobs' do
    job = MyJob.perform_later('MyApplicationJob.runs << "my_job_1"')
    expect { job.perform_now }.to change(MyApplicationJob, :runs).from([]).to(['my_job_1'])
  end

  it 'deletes records' do
    job = MyJob.perform_later
    expect { job.perform_now }.to change(MyRecord, :count).from(1).to(0)
  end
end
