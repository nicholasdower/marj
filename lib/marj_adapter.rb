# frozen_string_literal: true

# ActiveJob queue adapter for Marj.
#
# See https://github.com/nicholasdower/marj
class MarjAdapter
  # Enqueue a job for immediate execution.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @return [ActiveJob::Base] the enqueued job
  def enqueue(job)
    MarjRecord.send(:enqueue, job)
  end

  # Enqueue a job for execution at the specified time.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
  # @return [ActiveJob::Base] the enqueued job
  def enqueue_at(job, timestamp)
    MarjRecord.send(:enqueue, job, timestamp ? Time.at(timestamp).utc : nil)
  end
end
