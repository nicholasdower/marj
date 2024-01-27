# frozen_string_literal: true

require_relative 'jobs_interface'

module Marj
  # Returned by {Marj::JobsInterface} query methods to enable chaining and +Enumerable+ methods.
  class Relation
    include Enumerable
    include Marj::JobsInterface

    # Returns a Marj::Relation which wraps the specified +ActiveRecord+ relation.
    def initialize(ar_relation)
      @ar_relation = ar_relation
    end

    # (see Marj::JobsInterface#queue)
    def queue(queue, *queues)
      Marj::Relation.new(@ar_relation.where(queue_name: queues.dup.unshift(queue)))
    end

    # (see Marj::JobsInterface#next)
    def next(limit = nil)
      @ar_relation.first(limit)&.then { _1.is_a?(Array) ? _1.map(&:as_job) : _1.as_job }
    end

    # (see Marj::JobsInterface#count)
    def count(column_name = nil, &block)
      block_given? ? @ar_relation.count(column_name) { |r| block.call(r.as_job) } : @ar_relation.count(column_name)
    end

    # (see Marj::JobsInterface#where)
    def where(*args)
      Marj::Relation.new(@ar_relation.where(*args))
    end

    # (see Marj::JobsInterface#due)
    def due
      Marj::Relation.new(@ar_relation.due)
    end

    # (see Marj::JobsInterface#perform_all)
    def perform_all(batch_size: nil)
      if batch_size
        [].tap do |results|
          while (jobs = @ar_relation.limit(batch_size).map(&:as_job)).any?
            results.concat(jobs.map { |job| ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now } })
          end
        end
      else
        @ar_relation.map(&:as_job).map { |job| ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now } }
      end
    end

    # (see Marj::JobsInterface#discard_all)
    def discard_all
      @ar_relation.delete_all
    end

    # Yields each job in this relation.
    #
    # @param block [Proc]
    # @return [Array] the jobs in this relation
    def each(&block)
      @ar_relation.map(&:as_job).each(&block)
    end

    # Provides +pretty_inspect+ output containing arrays of jobs rather than arrays of records, similar to the output
    # produced when calling +pretty_inspect+ on +ActiveRecord::Relation+.
    #
    # Instead of the default +pretty_inspect+ output:
    #   > Marj.all
    #    =>
    #   #<Marj::Relation:0x000000012728bd88
    #    @ar_relation=
    #     [#<Marj::Record:0x0000000126c42080
    #       job_id: "1382cb98-c518-46ca-a0cc-d831e11a0714",
    #       job_class: TestJob,
    #       arguments: ["foo"],
    #       queue_name: "default",
    #       priority: nil,
    #       executions: 0,
    #       exception_executions: {},
    #       enqueued_at: 2024-01-25 15:31:06.115773 UTC,
    #       scheduled_at: nil,
    #       locale: "en",
    #       timezone: "UTC">]>
    #
    # Produces:
    #   > Marj.all
    #    =>
    #   [#<TestJob:0x000000010b63cef8
    #     @_scheduled_at_time=nil,
    #     @arguments=[],
    #     @enqueued_at=2024-01-25 15:31:06 UTC,
    #     @exception_executions={},
    #     @executions=0,
    #     @job_id="1382cb98-c518-46ca-a0cc-d831e11a0714",
    #     @locale="en",
    #     @priority=nil,
    #     @provider_job_id=nil,
    #     @queue_name="default",
    #     @scheduled_at=nil,
    #     @serialized_arguments=["foo"],
    #     @timezone="UTC">]
    #
    # @param pp [PP]
    # @return [NilClass]
    def pretty_print(pp)
      pp.pp(to_a)
    end
  end
end
