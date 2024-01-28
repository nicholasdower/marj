# frozen_string_literal: true

require_relative 'jobs_interface'

module Marj
  # Returned by {Marj::JobsInterface} query methods to enable chaining and +Enumerable+ methods.
  class Relation
    include Enumerable
    include Marj::JobsInterface

    attr_reader :all
    private :all

    # Returns a {Marj::Relation} which wraps the specified +ActiveRecord+ relation.
    def initialize(ar_relation)
      @all = ar_relation
    end

    # Yields each job in this relation.
    #
    # @param block [Proc]
    # @return [Array] the jobs in this relation
    def each(&block)
      all.map(&:as_job).each(&block)
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
