# frozen_string_literal: true

require 'active_job'
require 'active_record'

module Marj
  # The default +ActiveRecord+ class.
  class Record < ActiveRecord::Base
    self.table_name = :jobs

    # Order by +enqueued_at+ rather than +job_id+ (the default).
    self.implicit_order_column = 'enqueued_at'

    # Using a custom serializer for exception_executions so that we can interact with it as a hash rather than a
    # string.
    serialize(:exception_executions, coder: JSON)

    # Using a custom serializer for arguments so that we can interact with as an array rather than a string.
    # This enables code like:
    #   Marj::Record.next.arguments.first
    #   Marj::Record.next.update!(arguments: ['foo', 1, Time.now])
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

    # Returns a job object for this record which will update the database when successfully executed, enqueued or
    # discarded.
    #
    # @return [ActiveJob::Base]
    def to_job
      # See register_callbacks for details on how callbacks are used.
      job = job_class.new.tap { register_callbacks(_1) }

      # ActiveJob::Base#deserialize expects serialized arguments. But the record arguments have already been
      # deserialized by a custom ActiveRecord serializer (see below). So instead we use the raw arguments string.
      job_data = attributes.merge('arguments' => JSON.parse(read_attribute_before_type_cast(:arguments)))

      # ActiveJob::Base#deserialize expects dates to be strings rather than Time objects.
      job_data = job_data.to_h { |k, v| [k, %w[enqueued_at scheduled_at].include?(k) ? v&.iso8601 : v] }

      job.deserialize(job_data)

      # ActiveJob deserializes arguments on demand when a job is performed. Until then they are empty. That's strange.
      # Instead, deserialize them now. Also, clear `serialized_arguments` to prevent ActiveJob from overwriting changes
      # to arguments when serializing later.
      job.arguments = arguments
      job.serialized_arguments = nil

      job
    end

    # Registers callbacks for the given job which destroy this record when the job succeeds or is discarded.
    #
    # @param job [ActiveJob::Base]
    # @return [ActiveJob::Base]
    def register_callbacks(job)
      raise 'callbacks already registered' if job.singleton_class.instance_variable_get(:@record)

      record = self
      # We need to detect three cases:
      #  - If a job succeeds, after_perform will be called.
      #  - If a job fails and should be retried, enqueue will be called. This is handled by the queue adapter.
      #  - If a job exceeds its max attempts, after_discard will be called.
      job.singleton_class.after_perform { |_j| record.destroy! }
      job.singleton_class.after_discard { |_j, _exception| record.destroy! }
      job.singleton_class.instance_variable_set(:@record, record)

      job
    end
    private :register_callbacks

    class << self
      # Returns an +ActiveRecord::Relation+ scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in
      # the past.
      #
      # @return [ActiveRecord::Relation]
      def due
        where('scheduled_at IS NULL OR scheduled_at <= ?', Time.now.utc)
      end

      # Returns an +ActiveRecord::Relation+ scope for jobs ordered by due date.
      #
      # Jobs are ordered by the following criteria, in order:
      # 1. past or null scheduled_at before future scheduled_at
      # 2. ascending priority, nulls last
      # 3. ascending scheduled_at, nulls last
      # 4. ascending enqueued_at
      #
      # @return [ActiveRecord::Relation]
      def by_due_date
        order(
          Arel.sql(<<~SQL.squish, Time.now.utc)
            CASE WHEN scheduled_at IS NULL OR scheduled_at <= ? THEN 0 ELSE 1 END,
            CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority,
            CASE WHEN scheduled_at IS NULL THEN 1 ELSE 0 END, scheduled_at,
            enqueued_at
          SQL
        )
      end
    end
  end
end
