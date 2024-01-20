# frozen_string_literal: true

# ActiveJob queue adapter for Marj.
#
# If using Rails, configure via Rails::Application:
#
#   require 'marj'
#
#   class MyApplication < Rails::Application
#     config.active_job.queue_adapter = :marj
#   end
#
# If not using Rails, configure via ActiveJob::Base:
#
#   require 'marj'
#   require 'marj_record'
#   ActiveJob::Base.queue_adapter = :marj
#
# Alternatively, configure for a single job:
#
#   require 'marj'
#   require 'marj_record' # if not using Rails
#
#   class SomeJob < ActiveJob::Base
#     queue_adapter = :marj
#   end
class MarjAdapter
  # Enqueue a job for immediate execution.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @return [ActiveJob::Base] the enqueued job
  def enqueue(job)
    enqueue_at(job, nil)
  end

  # Enqueue a job for execution at the specified time.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
  # @return [ActiveJob::Base] the enqueued job
  def enqueue_at(job, timestamp)
    job.scheduled_at = timestamp ? Time.at(timestamp).utc : nil
    serialized = job.serialize.symbolize_keys!.without(:provider_job_id).merge(arguments: job.arguments)
    Marj.find_by(job_id: job.job_id)&.update!(serialized) || Marj.create!(serialized)
    Marj.send(:register_callbacks, job)
    job
  end
end
