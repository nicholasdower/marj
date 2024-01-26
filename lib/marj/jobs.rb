# frozen_string_literal: true

require_relative 'relation'

module Marj
  # Provides methods for querying, performing and discarding jobs.
  #
  # To create a custom query interface, for instance on a job class:
  #   FooJob < ActiveJob::Base
  #     self.class.include Marj::Jobs::ClassMethods
  #
  #     def self.all
  #       Marj::Relation.new(Marj::Record.where(job_class: Foo).all)
  #     end
  #   end
  #
  #   FooJob.first
  module Jobs
    # Class methods for {Marj::Jobs}. Can be used to create a custom jobs class.
    module ClassMethods
      # Returns a {Marj::Relation} for all jobs.
      #
      # @return [Marj::Relation]
      def all
        Marj::Relation.new(Marj::Record.all)
      end

      # Returns the first job or +nil+ if there aren't any jobs.
      #
      # @return [ActiveJob::Base, NilClass]
      def first
        all.first
      end

      # Returns the last job or +nil+ if there aren't any jobs.
      #
      # @return [ActiveJob::Base, NilClass]
      def last
        all.last
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
      # @return [Array] the results returned by each job
      def perform_all
        all.perform_all
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
