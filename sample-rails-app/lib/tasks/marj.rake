# frozen_string_literal: true

require 'English'
namespace :marj do
  desc 'Test Marj'
  task test_marj: :environment do
    loaded = false
    ActiveSupport.on_load(:active_record) { loaded = true }
    raise 'ActiveRecord loaded too soon' if loaded

    Marj.query(:count)
    raise 'ActiveRecord not loaded' unless loaded

    Marj.query(:delete_all)
    raise 'Unexpected job found' unless Marj.query(:count).zero?

    TestJob.perform_later('TestJob.runs << 1')
    raise 'Job not enqueued' unless Marj.query(:count) == 1

    Marj.query(:first).perform_now
    raise 'Job not executed' unless TestJob.runs == [1]
    raise 'Job not deleted' unless Marj.query(:count).zero?

    TestJob.perform_later('raise "hi"')
    raise 'Job not enqueued' unless Marj.query(:first)&.executions = 0

    Marj.query(:first).perform_now
    raise 'Job not executed' unless (Marj.query(:first).executions = 1)

    Marj.query(:first).perform_now rescue e = $ERROR_INFO
    raise 'error not raised' unless e&.message == 'hi'
    raise 'Job not deleted' unless Marj.query(:count).zero?
  end

  desc 'Test Mission Control Query'
  task test_mission_control_query: :environment do
    Marj.query(:delete_all)
    raise 'Unexpected job found' unless Marj.query(:count).zero?

    server = MissionControl::Jobs::Server.from_global_id('railssample:marj')
    MissionControl::Jobs::Current.server = server

    jobs = []
    jobs << TestJob.set(queue: 'foo').perform_later
    jobs << TestJob.set(queue: 'foo').perform_later
    jobs << TestJob.set(queue: 'bar').perform_later
    jobs << TestJob.set(queue: 'bar').perform_later
    jobs << TestJob.set(queue: 'bar').perform_later
    raise 'Jobs not found' unless ActiveJob.jobs.count == 5
    raise 'Jobs not found' unless ActiveJob.jobs.map(&:job_id).sort == jobs.map(&:job_id).sort

    found = ActiveJob.jobs.find_by_id(jobs.first.job_id)
    raise 'Job not found' unless jobs.first.job_id == found.job_id

    queues = ActiveJob.queues.sort_by(&:name)
    raise "Unexpected queues: #{queues.map(&:name)}" unless queues.map(&:name) == %w[bar foo]
    raise "Unexpected queue statuses: #{queues.map(&:active?)}" unless queues.map(&:active?) == [true, true]
    raise "Unexpected queue sizes: #{queues.map(&:size)}" unless queues.map(&:size) == [3, 2]

    first_id = ActiveJob.jobs.limit(1).to_a.first.job_id
    raise 'Jobs not limited' unless jobs.map(&:job_id).include?(first_id)

    second_id = ActiveJob.jobs.offset(1).limit(1).to_a.first.job_id
    raise 'Jobs not offset' unless jobs.map(&:job_id).include?(second_id) && second_id != first_id

    ActiveJob.jobs.discard_job(ActiveJob.jobs.find_by_id(jobs.first.job_id))
    jobs.shift
    raise 'Job not discarded' unless ActiveJob.jobs.map(&:job_id).sort == jobs.map(&:job_id).sort

    ActiveJob.jobs.where(queue_name: 'foo').discard_all
    jobs.shift
    raise 'Job not discarded' unless ActiveJob.jobs.map(&:job_id).sort == jobs.map(&:job_id).sort

    ActiveJob.jobs.discard_all
    raise 'Jobs not discarded' unless ActiveJob.jobs.empty?

    jobs = []
    jobs << TestJob.set(queue: 'foo').perform_later
    raise 'Scheduled found' unless ActiveJob.jobs.scheduled.count.zero?

    jobs << OtherJob.set(wait: 5.minutes, queue: 'bar').perform_later
    raise 'Scheduled not found' unless ActiveJob.jobs.with_status(:scheduled).map(&:job_id) == [jobs.second.job_id]
    raise 'Scheduled not found' unless ActiveJob.jobs.scheduled.map(&:job_id) == [jobs.second.job_id]

    raise 'Class not found' unless ActiveJob.jobs.where(job_class_name: TestJob).map(&:job_id) == [jobs.first.job_id]
    raise 'Pending not found' unless ActiveJob.jobs.with_status(:pending).map(&:job_id).sort == jobs.map(&:job_id).sort
    raise 'Pending not found' unless ActiveJob.jobs.pending.map(&:job_id).sort == jobs.map(&:job_id).sort
    raise 'Failed found' unless ActiveJob.jobs.failed.count.zero?

    job = OtherJob.perform_later('raise "hi"')
    job.perform_now
    raise 'Failed not found' unless ActiveJob.jobs.with_status(:failed).map(&:job_id) == [job.job_id]
    raise 'Failed not found' unless ActiveJob.jobs.failed.map(&:job_id) == [job.job_id]
  end

  desc 'Test Mission Control Retry'
  task test_mission_control_retry: :environment do
    Marj.query(:delete_all)
    raise 'Unexpected job found' unless Marj.query(:count).zero?

    server = MissionControl::Jobs::Server.from_global_id('railssample:marj')
    MissionControl::Jobs::Current.server = server

    job = TestJob.perform_later('executions == 1 ? raise("hi") : TestJob.runs << 1')
    job.perform_now
    raise 'Failed job not found' unless ActiveJob.jobs.failed.count == 1
    raise 'Job already ran' unless TestJob.runs.empty?

    ActiveJob.jobs.failed.retry_all
    raise 'Failed job found' unless ActiveJob.jobs.count.zero?
    raise 'Job not run' unless TestJob.runs == [1]

    TestJob.runs.clear
    job = TestJob.perform_later('TestJob.runs << 1; raise "hi"')
    job.perform_now
    raise 'Job not run' unless TestJob.runs == [1]

    TestJob.runs.clear
    begin
      ActiveJob.jobs.failed.retry_job(ActiveJob.jobs.find_by_id(job.job_id))
      raise 'Job did not raise'
    rescue StandardError => e
      raise unless e.message == 'hi'
    end
    raise 'Job not retried' unless TestJob.runs == [1]
  end
end
