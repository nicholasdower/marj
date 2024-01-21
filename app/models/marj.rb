# frozen_string_literal: true

require 'active_record'

# Marj is a Minimal ActiveRecord-based Jobs library.
#
# See https://github.com/nicholasdower/marj
class Marj < ActiveRecord::Base
  # The Marj version.
  VERSION = '1.0.0.pre'

  self.table_name = 'jobs'
  self.implicit_order_column = 'enqueued_at' # Order by +enqueued_at+ rather than +job_id+ (the default)

  serialize(:exception_executions, coder: JSON)
  serialize(:arguments, coder: Class.new do
    def self.dump(arguments)
      return ActiveJob::Arguments.serialize(arguments).to_json if arguments.is_a?(Array)
      return arguments if arguments.is_a?(String) || arguments.nil?

      raise "invalid arguments: #{arguments}"
    end

    def self.load(arguments)
      arguments ? ActiveJob::Arguments.deserialize(JSON.parse(arguments)) : nil
    end
  end)
  serialize(:job_class, coder: Class.new do
    def self.dump(clazz)
      return clazz.name if clazz.is_a?(Class)
      return clazz if clazz.is_a?(String) || clazz.nil?

      raise "invalid class: #{clazz}"
    end

    def self.load(str)
      str&.constantize
    end
  end)

  # Returns an ActiveRecord::Relation scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in the
  # past. Jobs are ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
  #
  # @return [ActiveRecord::Relation]
  def self.available
    where('scheduled_at is null or scheduled_at <= ?', Time.now.utc).order(
      Arel.sql(<<~SQL.squish)
        CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority,
        CASE WHEN scheduled_at IS NULL THEN 1 ELSE 0 END, scheduled_at,
        enqueued_at
      SQL
    )
  end

  # Executes any available jobs from the specified source.
  #
  # @param source [Proc] a job source
  # @return [NilClass]
  def self.work_off(source = -> { Marj.available.first })
    while (record = source.call)
      executions = record.executions
      begin
        record.execute
      rescue Exception
        # The job should either be discarded or have its executions incremented. Otherwise, something went wrong.
        raise unless record.destroyed? || record.executions == executions + 1
      end
    end
  end

  # Registers job callbacks used to keep the database record for the specified job in sync.
  #
  # @param job [ActiveJob::Base]
  # @return [ActiveJob::Base]
  def self.register_callbacks(job, record)
    return if job.singleton_class.instance_variable_get(:@__marj)

    job.singleton_class.before_perform { |j| j.successfully_enqueued = false } # To detect whether re-enqueued
    job.singleton_class.after_perform { |j| record.destroy! unless j.successfully_enqueued? }
    job.singleton_class.after_discard { |_j, _exception| record.destroy! }
    job.singleton_class.instance_variable_set(:@__marj, record)
    job
  end
  private_class_method :register_callbacks

  # Enqueue a job for execution at the specified time.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param time [Time, NilClass] optional time at which to execute the job
  # @return [ActiveJob::Base] the enqueued job
  def self.enqueue(job, time = nil)
    job.scheduled_at = time
    serialized = job.serialize.symbolize_keys!.without(:provider_job_id).merge(arguments: job.arguments)
    if (record = job.singleton_class.instance_variable_get(:@__marj))
      record.update!(serialized)
    else
      record = Marj.find_by(job_id: job.job_id)&.update!(serialized) || Marj.create!(serialized)
    end
    register_callbacks(job, record)
  end
  private_class_method :enqueue

  # Executes the job associated with this record and returns the result.
  def execute
    job = Marj.send(:register_callbacks, job_class.new, self)
    job_data = attributes.merge('arguments' => JSON.parse(read_attribute_before_type_cast(:arguments)))
    job_data['enqueued_at'] = job_data['enqueued_at']&.iso8601
    job_data['scheduled_at'] = job_data['scheduled_at']&.iso8601
    job.deserialize(job_data)
    ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now }
  end
end
