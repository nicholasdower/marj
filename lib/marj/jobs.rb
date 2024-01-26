# frozen_string_literal: true

require_relative 'relation'

module Marj
  # Provides methods for querying, performing and discarding jobs. Deals with +ActiveJob+ objects rather than
  # +ActiveRecord+ objects. To query the database directly, use {Marj::Record} instead.
  #
  # To create a query interface for all job classes:
  #   class ApplicationJob < ActiveJob::Base
  #     self.class.include Marj::Jobs::ClassMethods
  #
  #     def self.all
  #       Marj::Relation.new(self == ApplicationJob ? Marj::Record.all : Marj::Record.where(job_class: self))
  #     end
  #   end
  #
  #   ApplicationJob.first
  #   SomeJob.first
  #
  # To create a query interface for a single job class:
  #   class SomeJob < ActiveJob::Base
  #     self.class.include Marj::Jobs::ClassMethods
  #
  #     def self.all
  #       Marj::Relation.new(Marj::Record.where(job_class: self).all)
  #     end
  #   end
  #
  #   SomeJob.first
  #
  module Jobs
    # Class methods for {Marj::Jobs}. Can be used to create a custom jobs class.
    module ClassMethods
      # Returns a {Marj::Relation} for all jobs.
      #
      # @return [Marj::Relation]
      def all
        Marj::Relation.new(Marj::Record.all)
      end

      # Returns the first enqueued job or the first N enqueued jobs if +limit+ is specified. If no jobs are enqueued,
      # returns +nil+.
      #
      # @param limit [Integer, NilClass]
      # @return [ActiveJob::Base, NilClass]
      def first(limit = nil)
        all.first(limit)
      end

      # Returns the last enqueued job or the last N enqueued jobs if +limit+ is specified. If no jobs are enqueued,
      # returns +nil+.
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

      # Returns a {Marj::Relation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past. Jobs
      # are ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
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

      # Discards the specified job.
      #
      # @return [Integer] the number of discarded jobs
      def discard(job)
        all.where(job_id: job.job_id).discard_all
      end
    end

    self.class.include Marj::Jobs::ClassMethods
  end
end
