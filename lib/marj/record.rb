# frozen_string_literal: true

require_relative 'serializers/argument_serializer'
require_relative 'serializers/exception_executions_serializer'
require_relative 'serializers/job_class_serializer'
require_relative 'serializers/symbol_serializer'

module Marj
  # ActiveRecord model for jobs.
  class Record < ActiveRecord::Base
    self.table_name = 'jobs'

    serialize(:state, coder: Serializers::SymbolSerializer)
    serialize(:arguments, coder: Serializers::ArgumentsSerializer)
    serialize(:exception_executions, coder: Serializers::ExceptionExecutionsSerializer)
    serialize(:job_class, coder: Serializers::JobClassSerializer)

    # Overridden so that job records will be ordered by +enqueued_at+ rather than +job_id+ (the default).
    #
    # @return [String]
    def implicit_order_column
      'enqueued_at'
    end

    # Returns an ActiveRecord::Relation scope for jobs in the specified queue(s).
    #
    # @param queues [Array<String]
    # @return [ActiveRecord::Relation]
    def self.queue(*queues)
      where(queue_name: queues)
    end

    # Returns an ActiveRecord::Relation scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in the
    # past.
    #
    # @return [ActiveRecord::Relation]
    def self.executable
      where('scheduled_at is null or scheduled_at <= ?', Time.now.utc)
    end

    # Returns an ActiveRecord::Relation scope for {executable} jobs in order.
    #
    # Jobs are ordered by:
    # - +priority+ (+null+ last)
    # - +scheduled_at+ (+null+ last)
    # - +enqueued_at+
    #
    # @return [ActiveRecord::Relation]
    def self.ready
      executable.order(
        Arel.sql(
          <<~SQL.squish
            CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority,
            CASE WHEN scheduled_at IS NULL THEN 1 ELSE 0 END, scheduled_at,
            enqueued_at
          SQL
        )
      )
    end

    # Executes the job associated with this record and returns the result.
    def execute
      ActiveJob::Callbacks.run_callbacks(:execute) do
        Marj.send(:from, self).perform_now
      end
    end
  end
end
