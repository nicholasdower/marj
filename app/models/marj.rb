# frozen_string_literal: true

require 'active_job'
require 'active_record'
require_relative '../../lib/marj_config'

# Marj is a Minimal ActiveRecord-based Jobs library.
#
# See https://github.com/nicholasdower/marj
class Marj < ActiveRecord::Base
  # The Marj version.
  VERSION = '2.0.0'

  # Executes the job associated with this record and returns the result.
  def execute
    # Normally we would call ActiveJob::Base#execute which has the following implementation:
    #   ActiveJob::Callbacks.run_callbacks(:execute) do
    #     job = deserialize(job_data)
    #     job.perform_now
    #   end
    # However, we need to instantiate the job ourselves in order to register callbacks before execution.
    ActiveJob::Callbacks.run_callbacks(:execute) do
      # See register_callbacks for details on how callbacks are used.
      job = job_class.new.tap { Marj.send(:register_callbacks, _1, self) }

      # ActiveJob::Base#deserialize expects serialized arguments. But the record arguments have already been
      # deserialized by a custom ActiveRecord serializer (see below). So instead we use the raw arguments string.
      job_data = attributes.merge('arguments' => JSON.parse(read_attribute_before_type_cast(:arguments)))

      # ActiveJob::Base#deserialize expects dates to be strings rather than Time objects.
      job_data = job_data.to_h { |k, v| [k, %w[enqueued_at scheduled_at].include?(k) ? v&.iso8601 : v] }
      job.deserialize(job_data)

      new_executions = executions + 1
      job.perform_now.tap do
        # If no error was raised, the job should either be destroyed (success) or updated (retryable failure).
        raise "job #{job_id} not destroyed or updated" unless destroyed? || (executions == new_executions && !changed?)
      end
    end
  end

  # Returns an ActiveRecord::Relation scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in the
  # past. Jobs are ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
  #
  # @return [ActiveRecord::Relation]
  def self.ready
    where('scheduled_at is null or scheduled_at <= ?', Time.now.utc).order(
      Arel.sql(<<~SQL.squish)
        CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority,
        CASE WHEN scheduled_at IS NULL THEN 1 ELSE 0 END, scheduled_at,
        enqueued_at
    SQL
    )
  end

  self.table_name = MarjConfig.table_name

  # Order by +enqueued_at+ rather than +job_id+ (the default)
  self.implicit_order_column = 'enqueued_at'

  # Using a custom serializer for exception_executions so that we can interact with it as a hash rather than a string.
  serialize(:exception_executions, coder: JSON)

  # Using a custom serializer for arguments so that we can interact with as an array rather than a string.
  # This enables code like:
  #   Marj.first.arguments.first
  #   Marj.first.update!(arguments: ['foo', 1, Time.now])
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

  # Using a custom serializer for job_class so that we can interact with it as a class rather than a string.
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

  # Registers job callbacks used to keep the database record for the specified job in sync.
  #
  # @param job [ActiveJob::Base]
  # @return [ActiveJob::Base]
  def self.register_callbacks(job, record)
    raise 'callbacks already registered' if job.singleton_class.instance_variable_get(:@__marj)

    # We need to detect three cases:
    #  - If a job succeeds, after_perform will be called.
    #  - If a job fails and should be retried, enqueue will be called. This is handled by the enqueue method.
    #  - If a job exceeds its max attempts, after_discard will be called.
    job.singleton_class.after_perform { |_j| record.destroy! }
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
    # Argument serialization is done by ActiveJob. ActiveRecord expects deserialized arguments.
    serialized = job.serialize.symbolize_keys!.without(:provider_job_id).merge(arguments: job.arguments)

    # When a job is enqueued, we must create/update the corresponding database record. We also must ensure callbacks are
    # registered on the job instance so that when the job is executed, the database record is deleted or updated
    # (depending on the result).
    #
    # There are three cases:
    #  - The first time a job is enqueued, we need to create the record and register callbacks.
    #  - If a previously enqueued job instance is re-enqueued, for instance after execution fails, callbacks have
    #    already been registered. In this case we only need to update the record.
    #  - It is also possible for new job instance to be created for a job that is already in the database. In this case
    #    we need to update the record and register callbacks.
    #
    # We keep track of whether callbacks have been registered by setting the @__marj instance variable on the job's
    # singleton class. This holds a reference to the record. This allows us to update the record without re-fetching it
    # and also ensures that if execute is called on a record any updates to the database are reflected on that record
    # instance.
    if (record = job.singleton_class.instance_variable_get(:@__marj))
      record.update!(serialized)
    else
      record = Marj.find_or_create_by!(job_id: job.job_id) { _1.assign_attributes(serialized) }
      register_callbacks(job, record)
    end
    job
  end
  private_class_method :enqueue
end
