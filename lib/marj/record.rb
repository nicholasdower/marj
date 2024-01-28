# frozen_string_literal: true

require 'active_job'
require 'active_record'

module Marj
  # The default +ActiveRecord+ class.
  class Record < ActiveRecord::Base
    self.table_name = Marj.table_name

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
    def as_job
      Marj.send(:to_job, self)
    end

    class << self
      # Returns an +ActiveRecord::Relation+ scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in
      # the past.
      #
      # @return [ActiveRecord::Relation]
      def due
        where('scheduled_at IS NULL OR scheduled_at <= ?', Time.now.utc)
      end

      # Returns an +ActiveRecord::Relation+ scope for jobs ordered by +priority+ (+null+ last), then +scheduled_at+
      # (+null+ last), then +enqueued_at+.
      #
      # @return [ActiveRecord::Relation]
      def ordered
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
