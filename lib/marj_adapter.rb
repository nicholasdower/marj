# frozen_string_literal: true

# ActiveJob queue adapter for Marj.
#
# In addition to the standard +ActiveJob+ queue adapter API, this adapter provides:
# - A +query+ method which can be used to query enqueued jobs
# - A +discard+ method which can be used to discard enqueued jobs.
# - A +delete+ method which can be used to delete enqueued jobs.
#
# Although it is possible to access the adapter directly in order to query, discard or delete, it is recommended to use
# the {Marj} module.
#
# See https://github.com/nicholasdower/marj
class MarjAdapter
  JOB_ID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.freeze
  private_constant :JOB_ID_REGEX

  # Creates a new adapter which will enqueue jobs using the given +ActiveRecord+ class.
  #
  # @param record_class [Class, String] the +ActiveRecord+ class (or its name) to use, defaults to +Marj::Record+
  # @param discard [Proc] the proc to use to discard jobs, defaults to delegating to {delete}
  def initialize(record_class: 'Marj::Record', discard: proc { |job| delete(job) })
    @record_class = record_class
    @discard_proc = discard
  end

  # Enqueue a job for immediate execution.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @return [ActiveJob::Base] the enqueued job
  def enqueue(job)
    enqueue_at(job)
  end

  # Enqueue a job for execution at the specified time.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
  # @return [ActiveJob::Base] the enqueued job
  def enqueue_at(job, timestamp = nil)
    job.scheduled_at = timestamp ? Time.at(timestamp).utc : nil

    # Argument serialization is done by ActiveJob. ActiveRecord expects deserialized arguments.
    serialized = job.serialize.symbolize_keys!.without(:provider_job_id).merge(arguments: job.arguments)

    # Serialize sets locale to I18n.locale.to_s and enqueued_at to Time.now.utc.iso8601(9).
    # Update the job to reflect what is being enqueued.
    job.locale = serialized[:locale]
    job.enqueued_at = Time.iso8601(serialized[:enqueued_at]).utc

    # When a job is enqueued, we must create/update the corresponding database record. We also must ensure callbacks
    # are registered on the job instance so that when the job is executed, the database record is deleted or updated
    # (depending on the result).
    #
    # We keep track of whether callbacks have been registered by setting the @record instance variable on the job's
    # singleton class. This holds a reference to the record. This ensures that if execute is called on a record
    # instance, any updates to the database are reflected on that record instance.
    if (existing_record = job.singleton_class.instance_variable_get(:@record))
      # This job instance has already been associated with a database row.
      if record_class.exists?(job_id: job.job_id)
        # The database row still exists, we simply need to update it.
        existing_record.update!(serialized)
      else
        # Someone else deleted the database row, we need to recreate and reload the existing record instance. We don't
        # want to register the new instance because someone might still have a reference to the existing one.
        record_class.create!(serialized)
        existing_record.reload
      end
    else
      # This job instance has not been associated with a database row.
      if (new_record = record_class.find_by(job_id: job.job_id))
        # The database row already exists. Update it.
        new_record.update!(serialized)
      else
        # The database row does not exist. Create it.
        new_record = record_class.create!(serialized)
      end
      new_record.send(:register_callbacks, job)
    end
    job
  end

  # Queries enqueued jobs. Similar to +ActiveRecord.where+ with a few additional features:
  # - Symbol arguments are treated as +ActiveRecord+ scopes.
  # - If only a job ID is specified, the corresponding job is returned.
  # - If +:limit+ is specified, the maximum number of jobs is limited.
  # - If +:order+ is specified, the jobs are ordered by the given attribute.
  #
  # By default jobs are ordered by when they should be executed.
  #
  # Example usage:
  #   query                       # Returns all jobs
  #   query(:all)                 # Returns all jobs
  #   query(:due)                 # Returns jobs which are due to be executed
  #   query(:due, limit: 10)      # Returns at most 10 jobs which are due to be executed
  #   query(job_class: Foo)       # Returns all jobs with job_class Foo
  #   query(:due, job_class: Foo) # Returns jobs which are due to be executed with job_class Foo
  #   query(queue_name: 'foo')    # Returns all jobs in the 'foo' queue
  #   query(job_id: '123')        # Returns the job with job_id '123' or nil if no such job exists
  #   query('123')                # Returns the job with job_id '123' or nil if no such job exists
  def query(*args, **kwargs)
    args, kwargs = args.dup, kwargs.dup.symbolize_keys
    kwargs = kwargs.merge(job_id: kwargs.delete(:id)) if kwargs.key?(:id)
    kwargs[:job_id] = args.shift if args.size == 1 && args.first.is_a?(String) && args.first.match(JOB_ID_REGEX)

    if args.empty? && kwargs.size == 1 && kwargs.key?(:job_id)
      return record_class.find_by(job_id: kwargs[:job_id])&.to_job
    end

    symbol_args, args = args.partition { _1.is_a?(Symbol) }
    symbol_args.delete(:all)
    limit = kwargs.delete(:limit)
    relation = record_class.all
    relation = relation.order(kwargs.delete(:order)) if kwargs.key?(:order)
    relation = relation.where(*args, **kwargs) if args.any? || kwargs.any?
    relation = relation.limit(limit) if limit
    relation = relation.send(symbol_args.shift) while symbol_args.any?
    relation = relation.by_due_date if relation.is_a?(ActiveRecord::Relation) && relation.order_values.empty?

    if relation.is_a?(Enumerable)
      relation.map(&:to_job)
    elsif relation.is_a?(record_class)
      relation.to_job
    else
      relation
    end
  end

  # Discards the specified job.
  #
  # @param job [ActiveJob::Base] the job being discarded
  # @param run_callbacks [Boolean] whether to run the +after_discard+ callbacks
  # @return [ActiveJob::Base] the discarded job
  def discard(job, run_callbacks: true)
    job.tap do
      @discard_proc.call(job)
      run_after_discard_callbacks(job) if run_callbacks
    end
  end

  # Deletes the record associated with the specified job.
  #
  # @return [ActiveJob::Base] the deleted job
  def delete(job)
    job.tap { destroy_record(job) }
  end

  private

  # Returns the +ActiveRecord+ class to use to store jobs.
  #
  # @return [Class] the +ActiveRecord+ class
  def record_class
    @record_class = @record_class.is_a?(String) ? @record_class.constantize : @record_class
  end

  # Destroys the record associated with the given job if it exists.
  #
  # @return [ActiveRecord::Base, NilClass] the destroyed record or +nil+ if no such record exists
  def destroy_record(job)
    record = job.singleton_class.instance_variable_get(:@record)
    record ||= Marj::Record.find_by(job_id: job.job_id)&.tap { _1.send(:register_callbacks, job) }
    record&.destroy
  end

  # Invokes the specified job's +after_discard+ callbacks.
  #
  # @param job [ActiveJob::Base] the job being discarded
  # @return [NilClass] the given job
  def run_after_discard_callbacks(job)
    # Copied from ActiveJob::Exceptions#run_after_discard_procs
    exceptions = []
    job.after_discard_procs.each do |blk|
      instance_exec(job, nil, &blk)
    rescue StandardError => e
      exceptions << e
    end
    raise exceptions.last if exceptions.any?

    nil
  end
end
