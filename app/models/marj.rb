# frozen_string_literal: true

require 'active_record'

# Marj is a Minimal ActiveRecord-based Jobs library.
#
# Setup:
#
# If using Rails:
#
#   require 'marj'
#
#   # Configure via Rails::Application:
#   class MyApplication < Rails::Application
#     config.active_job.queue_adapter = :marj
#   end
#
#   # Or for specific jobs:
#   class SomeJob < ActiveJob::Base
#     self.queue_adapter = :marj
#   end
#
# If not using Rails:
#
#   require 'marj'
#   require 'marj_record'
#
#   # Configure via ActiveJob::Base:
#   ActiveJob::Base.queue_adapter = :marj
#
#   # Or for specific jobs:
#   class SomeJob < ActiveJob::Base
#     self.queue_adapter = :marj
#   end
#
# Example Usage:
#   # Enqueue and manually run a job:
#   job = SampleJob.perform_later('foo')
#   job.perform_now
#
#   # Enqueue, retrieve and manually run a job:
#   SampleJob.perform_later('foo')
#   Marj.first.execute
#
#   # Run all available jobs:
#   Marj.work_off
#
#   # Run jobs as they become available:
#   Marj.start_worker
class Marj < ActiveRecord::Base
  # The Marj version.
  VERSION = '1.0.0.pre'

  self.table_name = 'jobs'
  self.implicit_order_column = 'enqueued_at' # Order by +enqueued_at+ rather than +job_id+ (the default)

  # Serializer for the +arguments+ column.
  class ArgumentsSerializer
    # Returns a string representation of +arguments+.
    #
    # @param arguments [Array, String, NilClass]
    # @return [String]
    def self.dump(arguments)
      if arguments.is_a?(Array)
        return ActiveJob::Arguments.serialize(arguments).to_json
      elsif arguments.is_a?(String) || arguments.nil?
        return arguments
      end

      raise "invalid arguments: #{arguments}"
    end

    # Converts a string representation of an +arguments+ array into a an array
    #
    # @param arguments [String]
    # @return [Array]
    def self.load(arguments)
      arguments ? ActiveJob::Arguments.deserialize(JSON.parse(arguments)) : nil
    end
  end
  private_constant :ArgumentsSerializer

  # Serializer for class objects.
  class ClassSerializer
    # Returns a string representation of class.
    #
    # @param clazz [Class, String, NilClass]
    # @return [String]
    def self.dump(clazz)
      if clazz.is_a?(Class)
        return clazz.name
      elsif clazz.is_a?(String) || clazz.nil?
        return clazz
      end

      raise "invalid class: #{clazz}"
    end

    # Converts a string representation of a class into a class.
    #
    # @param str [String, NilClass]
    # @return [Class]
    def self.load(str)
      str&.constantize
    end
  end
  private_constant :ClassSerializer

  serialize(:arguments, coder: ArgumentsSerializer)
  serialize(:exception_executions, coder: JSON)
  serialize(:job_class, coder: ClassSerializer)

  # Returns an ActiveRecord::Relation scope for jobs in the specified queue(s).
  #
  # @param queues [Array<String]
  # @return [ActiveRecord::Relation]
  def self.queue(*queues)
    where(queue_name: queues)
  end

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
      begin
        record.execute
      rescue Exception
        # The job should either be discarded or have its executions incremented. Otherwise, something went wrong.
        raise if Marj.find_by(job_id: record.job_id)&.executions == record.executions
      end
    end
  end

  # Executes jobs from the specified source as they become available.
  #
  # @param source [Proc] a job source
  # @param delay [ActiveSupport::Duration] sleep duration after executing all available jobs, defaults to 5s
  # @return [void]
  def self.start_worker(source = -> { Marj.available.first }, delay: 5.seconds)
    loop do
      work_off(source)
      sleep delay.in_seconds
    end
  end

  # Registers job callbacks used to keep the database record for the specified job in sync.
  #
  # @param job [ActiveJob::Base]
  # @return [ActiveJob::Base]
  def self.register_callbacks(job)
    return if job.singleton_class.instance_variable_get(:@__marj)

    job.singleton_class.before_perform { |j| j.successfully_enqueued = false } # To detect whether re-enqueued
    job.singleton_class.after_perform { |j| Marj.find_by!(job_id: j.job_id).delete unless j.successfully_enqueued? }
    job.singleton_class.after_discard { |j, _| Marj.find_by!(job_id: j.job_id).delete }
    job.singleton_class.instance_variable_set(:@__marj, true)
    job
  end
  private_class_method :register_callbacks

  # Executes the job associated with this record and returns the result.
  def execute
    ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now }
  end

  # Creates a job object for this record.
  #
  # @return [ActiveJob::Base]
  def job
    job = Marj.send(:register_callbacks, job_class.new)
    job_data = attributes
    job_data['arguments'] = JSON.parse(read_attribute_before_type_cast(:arguments)) # Skip ArgumentsSerializer
    job_data['enqueued_at'] = job_data['enqueued_at']&.iso8601
    job_data['scheduled_at'] = job_data['scheduled_at']&.iso8601
    job.deserialize(job_data)
    job
  end
end
