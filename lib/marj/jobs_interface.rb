# frozen_string_literal: true

module Marj
  # The interface provided by {Marj} and {Marj::Relation}.
  #
  # To create a custom jobs interface, for example for all job classes in your application:
  #   class ApplicationJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(
  #         self == ApplicationJob ?
  #           Marj::Record.ordered : Marj::Record.where(job_class: self).ordered
  #       )
  #     end
  #   end
  #
  #   class SomeJob < ApplicationJob
  #     def perform(msg)
  #       puts msg
  #     end
  #   end
  #
  # This will allow you to query jobs via the +ApplicationJob+ class:
  #   ApplicationJob.next # Returns the next job of any type
  #
  # Or to query jobs via a specific job class:
  #   SomeJob.next # Returns the next SomeJob
  #
  # Alternatively, to create a jobs interface for a single job class:
  #   class SomeJob < ActiveJob::Base
  #     extend Marj::JobsInterface
  #
  #     def self.all
  #       Marj::Relation.new(Marj::Record.where(job_class: self).ordered)
  #     end
  #   end
  module JobsInterface
    def self.included(clazz)
      return if clazz == Marj::Relation

      clazz.delegate :queue, :next, :count, :where, :due, :perform_all, :discard_all, to: :all
    end
    private_class_method :included

    def self.extended(clazz)
      clazz.singleton_class.delegate :queue, :next, :count, :where, :due, :perform_all, :discard_all, to: :all
    end
    private_class_method :extended

    # Returns a {Marj::Relation} for jobs in the specified queue(s).
    #
    # @param queue [String, Symbol] the queue to query
    # @param queues [Array<String>, Array<Symbol>] more queues to query
    # @return [Marj::Relation]
    def queue(queue, *queues)
      Marj::Relation.new(all.where(queue_name: queues.dup.unshift(queue)))
    end

    # Returns the next job or the next N jobs if +limit+ is specified. If no jobs exist, returns +nil+.
    #
    # @param limit [Integer, NilClass]
    # @return [ActiveJob::Base, NilClass]
    def next(limit = nil)
      all.first(limit)&.then { _1.is_a?(Array) ? _1.map(&:as_job) : _1.as_job }
    end

    # Returns a count of jobs, optionally either matching the specified column name criteria or where the specified
    # block returns +true+.
    #
    # @param column_name [String, Symbol, NilClass]
    # @param block [Proc, NilClass]
    # @return [Integer]
    def count(column_name = nil, &block)
      block_given? ? all.count(column_name) { |r| block.call(r.as_job) } : all.count(column_name)
    end

    # Returns a {Marj::Relation} for jobs matching the specified criteria.
    #
    # @param args [Array]
    # @return [Marj::Relation]
    def where(*args)
      Marj::Relation.new(all.where(*args))
    end

    # Returns a {Marj::Relation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past.
    #
    # @return [Marj::Relation]
    def due
      Marj::Relation.new(all.due)
    end

    # Calls +perform_now+ on each job.
    #
    # @param batch_size [Integer, NilClass] the number of jobs to fetch at a time, or +nil+ to fetch all jobs at once
    # @return [Array] the results returned by each job
    def perform_all(batch_size: nil)
      if batch_size
        [].tap do |results|
          while (jobs = all.limit(batch_size).map(&:as_job)).any?
            results.concat(jobs.map { |job| ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now } })
          end
        end
      else
        all.map(&:as_job).map { |job| ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now } }
      end
    end

    # Discards all jobs.
    #
    # @return [Numeric] the number of discarded jobs
    def discard_all
      all.delete_all
    end
  end
end
