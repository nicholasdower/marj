# frozen_string_literal: true

module Marj
  # The interface provided by {Marj::Jobs} and {Marj::Relation}. Include to create a custom jobs interface.
  #
  # To create a jobs interface for all job classes:
  #   class ApplicationJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(self == ApplicationJob ? Marj::Record.all : Marj::Record.where(job_class: self))
  #     end
  #   end
  #
  #   ApplicationJob.first
  #   SomeJob.first
  #
  # To create a jobs interface for a single job class:
  #   class SomeJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(Marj::Record.where(job_class: self).all)
  #     end
  #   end
  #
  #   SomeJob.first
  module JobsInterface
    # Returns a {Marj::Relation} for jobs in the specified queue(s).
    #
    # @param queue [String, Symbol] the queue to query
    # @param queues [Array<String, Array<Symbol>] more queues to query
    # @return [Marj::Relation]
    def queue(queue, *queues)
      all.queue(queue, *queues)
    end

    # Returns the first job or the first N jobs if +limit+ is specified. If no jobs exist, returns +nil+.
    #
    # @param limit [Integer, NilClass]
    # @return [ActiveJob::Base, NilClass]
    def first(limit = nil)
      all.first(limit)
    end

    # Returns the last job or the last N jobs if +limit+ is specified. If no jobs exist, returns +nil+.
    #
    # @param limit [Integer, NilClass]
    # @return [ActiveJob::Base, NilClass]
    def last(limit = nil)
      all.last(limit)
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

    # Returns a {Marj::Relation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past. Jobs are
    # ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
    #
    # @return [Marj::Relation]
    def ready
      all.ready
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
