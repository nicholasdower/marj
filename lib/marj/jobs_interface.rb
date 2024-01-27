# frozen_string_literal: true

module Marj
  # The interface provided by {Marj} and {Marj::Relation}. Include to create a custom jobs interface.
  #
  # To create a jobs interface for all job classes:
  #   class ApplicationJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(self == ApplicationJob ? Marj::Record.ordered : Marj::Record.where(job_class: self))
  #     end
  #   end
  #
  #   ApplicationJob.next
  #   SomeJob.next
  #
  # To create a jobs interface for a single job class:
  #   class SomeJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(Marj::Record.where(job_class: self).ordered)
  #     end
  #   end
  #
  #   SomeJob.next
  module JobsInterface
    # Returns a {Marj::Relation} for jobs in the specified queue(s).
    #
    # @param queue [String, Symbol] the queue to query
    # @param queues [Array<String, Array<Symbol>] more queues to query
    # @return [Marj::Relation]
    def queue(queue, *queues)
      all.queue(queue, *queues)
    end

    # Returns the next job or the next N jobs if +limit+ is specified. If no jobs exist, returns +nil+.
    #
    # @param limit [Integer, NilClass]
    # @return [ActiveJob::Base, NilClass]
    def next(limit = nil)
      all.next(limit)
    end

    # Returns a count of jobs, optionally either matching the specified column name criteria or where the specified
    # block returns +true+.
    #
    # @param column_name [String, Symbol, NilClass]
    # @param block [Proc, NilClass]
    # @return [Integer]
    def count(column_name = nil, &block)
      all.count(column_name, &block)
    end

    # Returns a {Marj::Relation} for jobs matching the specified criteria.
    #
    # @param args [Array]
    # @return [Marj::Relation]
    def where(*args)
      all.where(*args)
    end

    # Returns a {Marj::Relation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past.
    #
    # @return [Marj::Relation]
    def due
      all.due
    end

    # Calls +perform_now+ on each job.
    #
    # @param batch_size [Integer, NilClass] the number of jobs to fetch at a time, or +nil+ to fetch all jobs at once
    # @return [Array] the results returned by each job
    def perform_all(batch_size: nil)
      all.perform_all(batch_size: batch_size)
    end

    # Discards all jobs.
    #
    # @return [Numeric] the number of discarded jobs
    def discard_all
      all.discard_all
    end
  end
end
