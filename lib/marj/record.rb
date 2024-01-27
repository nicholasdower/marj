# frozen_string_literal: true

require 'active_job'
require 'active_record'
require_relative '../marj'

module Marj
  # The Marj ActiveRecord model class.
  #
  # See https://github.com/nicholasdower/marj
  class Record < ActiveRecord::Base
    # Provides base functionality for {Marj::Record}. Can be used to create a custom +ActiveRecord+ model class.
    #
    # Example Usage:
    #   class MyRecord < ActiveRecord::Base
    #     include Marj::Record::Base
    #     extend Marj::Record::Base::ClassMethods
    #
    #     self.table_name = 'my_jobs'
    #   end
    module Base
      # Adds custom serializers and an implicit order column to the including class.
      #
      # @param clazz [Class] the including class
      def self.included(clazz)
        # Order by +enqueued_at+ rather than +job_id+ (the default)
        clazz.implicit_order_column = 'enqueued_at'

        # Using a custom serializer for exception_executions so that we can interact with it as a hash rather than a
        # string.
        clazz.serialize(:exception_executions, coder: JSON)

        # Using a custom serializer for arguments so that we can interact with as an array rather than a string.
        # This enables code like:
        #   Marj::Record.first.arguments.first
        #   Marj::Record.first.update!(arguments: ['foo', 1, Time.now])
        clazz.serialize(:arguments, coder: Class.new do
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
        clazz.serialize(:job_class, coder: Class.new do
          def self.dump(clazz)
            return clazz.name if clazz.is_a?(Class)
            return clazz if clazz.is_a?(String) || clazz.nil?

            raise "invalid class: #{clazz}"
          end

          def self.load(str)
            str&.constantize
          end
        end)
      end

      # Class methods for {Marj::Record::Base}.
      module ClassMethods
        # Returns an ActiveRecord::Relation scope for enqueued jobs with a +scheduled_at+ that is either +null+ or in
        # the past. Jobs are ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
        #
        # @return [ActiveRecord::Relation]
        def ready
          where('scheduled_at is null or scheduled_at <= ?', Time.now.utc).order(
            Arel.sql(<<~SQL.squish)
              CASE WHEN priority IS NULL THEN 1 ELSE 0 END, priority,
              CASE WHEN scheduled_at IS NULL THEN 1 ELSE 0 END, scheduled_at,
              enqueued_at
            SQL
          )
        end
      end

      # Returns a job object for this record which will update the database when successfully executed, enqueued or
      # discarded.
      #
      # @return [ActiveJob::Base]
      def as_job
        Marj.send(:to_job, self)
      end
    end

    include Marj::Record::Base
    extend Marj::Record::Base::ClassMethods

    self.table_name = 'jobs'
  end
end
