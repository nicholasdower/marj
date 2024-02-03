# frozen_string_literal: true

require_relative '../marj_adapter'
require 'mission_control/jobs'
require 'mission_control/jobs/adapter'

# :nocov:
module Marj
  module MissionControl
    include ::MissionControl::Jobs::Adapter

    def queues
      record_class.group(:queue_name).count(:queue_name).map { |k, v| { name: k, size: v, active: true } }
    end

    def queue_size(queue_name)
      record_class.where(queue_name: queue_name).count
    end

    def clear_queue(queue_name)
      Marj::Record.where(queue_name: queue_name).delete_all
    end

    def pause_queue(_queue_name)
      raise 'not supported: pause queue'
    end

    def resume_queue(_queue_name)
      raise 'not supported: resume queue'
    end

    def queue_paused?(_queue_name)
      false
    end

    def supported_statuses
      %i[pending failed scheduled]
    end

    def supported_filters(_jobs_relation)
      %i[queue_name job_class_name]
    end

    def exposes_workers?
      false
    end

    def workers
      raise 'not supported: workers'
    end

    def find_worker(_worker_id)
      raise 'not supported: find workers'
    end

    def jobs_count(jobs_relation)
      ar_relation(jobs_relation).count
    end

    def fetch_jobs(jobs_relation)
      ar_relation(jobs_relation).each_with_index.map { |record, index| to_job(record, jobs_relation, index) }
    end

    def retry_all_jobs(jobs_relation)
      ar_relation(jobs_relation).map { |record| record.to_job.perform_now }
    end

    def retry_job(job, _jobs_relation)
      Marj::Record.find(job.job_id).to_job.perform_now
    end

    def discard_all_jobs(jobs_relation)
      ar_relation(jobs_relation).map { |record| discard(record.to_job) }
    end

    def discard_job(job, _jobs_relation)
      discard(Marj::Record.find(job.job_id).to_job)
    end

    def find_job(job_id, jobs_relation)
      to_job(record_class.find_by(job_id: job_id), jobs_relation)
    end

    private

    def ar_relation(jobs_relation)
      relation = Marj::Record.all.offset(jobs_relation.offset_value).limit(jobs_relation.limit_value)
      relation = relation.where.not(executions: 0) if jobs_relation.status == :failed
      relation = relation.where.not(scheduled_at: nil) if jobs_relation.status == :scheduled
      relation = relation.where(job_class: jobs_relation.job_class_name) if jobs_relation.job_class_name
      relation = relation.where(queue_name: jobs_relation.queue_name) if jobs_relation.queue_name
      relation
    end

    def to_job(record, jobs_relation, index = 0)
      return nil unless record

      job = record.to_job
      job_data = job.serialize
      ActiveJob::JobProxy.new(job_data).tap do |proxy|
        if job.executions.positive?
          proxy.last_execution_error = ActiveJob::ExecutionError.new(
            error_class: Exception, message: 'unknown', backtrace: []
          )
          proxy.failed_at = job.enqueued_at
          proxy.status = :failed
        elsif job.scheduled_at
          proxy.status = :scheduled
        else
          proxy.status = :pending
        end
        proxy.raw_data = job_data
        proxy.position = jobs_relation.offset_value + index
        proxy.arguments = job.arguments # For some reason MissionControl sets the arguments to the entire job data
      end
    end
  end
end
# :nocov:
