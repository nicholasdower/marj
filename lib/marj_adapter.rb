# frozen_string_literal: true

# ActiveJob queue adapter for Marj.
#
# See https://github.com/nicholasdower/marj
class MarjAdapter
  # Creates a new adapter which will enqueue jobs using the given +ActiveRecord+ model class.
  #
  # @param record_class [Class, String] the +ActiveRecord+ model class (or its name) to use to store jobs
  def initialize(record_class = 'Marj::Record')
    @record_class = record_class
  end

  # Enqueue a job for immediate execution.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @return [ActiveJob::Base] the enqueued job
  def enqueue(job)
    Marj.send(:enqueue, job, record_class)
  end

  # Enqueue a job for execution at the specified time.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
  # @return [ActiveJob::Base] the enqueued job
  def enqueue_at(job, timestamp)
    Marj.send(:enqueue, job, record_class, timestamp ? Time.at(timestamp).utc : nil)
  end

  private

  def record_class
    @record_class = @record_class.is_a?(String) ? @record_class.constantize : @record_class
  end
end
