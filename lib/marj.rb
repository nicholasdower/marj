# frozen_string_literal: true

require_relative 'marj_adapter'
require_relative 'marj/jobs_interface'
require_relative 'marj/record_interface'
require_relative 'marj/relation'

# A minimal database-backed ActiveJob queueing backend.
#
# The {Marj} module extends the {Marj::JobsInterface} module to provide methods for querying, performing and discarding
# jobs. These methods accept, return and yield +ActiveJob+ objects rather than +ActiveRecord+ objects. To query the
# database directly, use {Marj::Record}.
#
# See https://github.com/nicholasdower/marj
module Marj
  # The Marj version.
  VERSION = '4.0.0.pre'

  Kernel.autoload(:Record, File.expand_path(File.join('marj', 'record.rb'), __dir__))

  class << self
    include Marj::JobsInterface

    # Returns a {Marj::Relation} for all jobs in the order they should be executed.
    #
    # @return [Marj::Relation]
    def all
      Marj::Relation.new(Marj::Record.ordered)
    end

    # Discards the specified job.
    #
    # @return [Integer] the number of discarded jobs
    def discard(job)
      all.where(job_id: job.job_id).discard_all
    end

    private

    # Creates a job instance for the given record which will update the database when successfully executed, enqueued or
    # discarded.
    #
    # @param record [ActiveRecord::Base]
    # @return [ActiveJob::Base] the new job instance
    def to_job(record)
      # See register_callbacks for details on how callbacks are used.
      job = record.job_class.new.tap { register_callbacks(_1, record) }

      # ActiveJob::Base#deserialize expects serialized arguments. But the record arguments have already been
      # deserialized by a custom ActiveRecord serializer (see below). So instead we use the raw arguments string.
      job_data = record.attributes.merge('arguments' => JSON.parse(record.read_attribute_before_type_cast(:arguments)))

      # ActiveJob::Base#deserialize expects dates to be strings rather than Time objects.
      job_data = job_data.to_h { |k, v| [k, %w[enqueued_at scheduled_at].include?(k) ? v&.iso8601 : v] }

      job.tap { job.deserialize(job_data) }
    end

    # Registers callbacks for the given job which destroy the given database record when the job succeeds or is
    # discarded.
    #
    # @param job [ActiveJob::Base]
    # @param record [ActiveRecord::Base]
    # @return [ActiveJob::Base]
    def register_callbacks(job, record)
      raise 'callbacks already registered' if job.singleton_class.instance_variable_get(:@record)

      # We need to detect three cases:
      #  - If a job succeeds, after_perform will be called.
      #  - If a job fails and should be retried, enqueue will be called. This is handled by the enqueue method.
      #  - If a job exceeds its max attempts, after_discard will be called.
      job.singleton_class.after_perform { |_j| record.destroy! }
      job.singleton_class.after_discard { |_j, _exception| record.destroy! }
      job.singleton_class.instance_variable_set(:@record, record)

      job
    end

    # Enqueue a job for execution at the specified time.
    #
    # @param job [ActiveJob::Base] the job to enqueue
    # @param record_class [Class] the +ActiveRecord+ model class
    # @param time [Time, NilClass] optional time at which to execute the job
    # @return [ActiveJob::Base] the enqueued job
    def enqueue(job, record_class, time = nil)
      job.scheduled_at = time
      # Argument serialization is done by ActiveJob. ActiveRecord expects deserialized arguments.
      serialized = job.serialize.symbolize_keys!.without(:provider_job_id).merge(arguments: job.arguments)

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
        register_callbacks(job, new_record)
      end
      job
    end
  end
end
