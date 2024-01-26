# frozen_string_literal: true

# Provides a small subset of the query and persistence methods provided by +ActiveRecord+ relations, but for jobs.
class MarjRelation
  include Enumerable

  # Returns a MarjRelation which wraps the specified +ActiveRecord+ relation.
  def initialize(ar_relation)
    @ar_relation = ar_relation
  end

  # Returns the first job in the relation, or +nil+ if the relation is empty.
  #
  # @return [ActiveJob::Base, NilClass]
  def first
    @ar_relation.first&.as_job
  end

  # Returns the last job in the relation, or +nil+ if the relation is empty.
  #
  # @return [ActiveJob::Base, NilClass]
  def last
    @ar_relation.last&.as_job
  end

  # Returns a count of jobs in this relation, optionally either matching the specified column name criteria or where the
  # specified block returns +true+.
  #
  # @param column_name [String, Symbol, NilClass]
  # @param block [Proc, NilClass]
  # @return [Integer]
  def count(column_name = nil, &block)
    block_given? ? @ar_relation.count(column_name) { |r| block.call(r.as_job) } : @ar_relation.count(column_name)
  end

  # Returns a {MarjRelation} for jobs matching the specified criteria.
  #
  # @param args [Array]
  # @return [MarjRelation]
  def where(*args)
    MarjRelation.new(@ar_relation.where(*args))
  end

  # Returns a {MarjRelation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past. Jobs are
  # ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
  #
  # @return [MarjRelation]
  def ready
    MarjRelation.new(@ar_relation.ready)
  end

  # Calls +perform_now+ on each job in this relation.
  #
  # @return [Array] the results returned by each job
  def perform_all
    @ar_relation.map(&:as_job).map { |job| ActiveJob::Callbacks.run_callbacks(:execute) { job.perform_now } }
  end

  # Discards all jobs in this relation.
  #
  # @return [Numeric] the number of discarded jobs
  def discard_all
    @ar_relation.delete_all
  end

  # Used by +Enumerable+ to iterate over the jobs in this relation.
  def each
    @ar_relation.map(&:as_job).each { yield _1 }
  end

  # Provides +pretty_inspect+ output containing arrays of jobs rather than arrays of records, similar to the output
  # produced when calling +pretty_inspect+ on +ActiveRecord::Relation+.
  #
  # Instead of the default +pretty_inspect+ output:
  #   > Marj.all
  #    =>
  #   #<MarjRelation:0x000000012728bd88
  #    @ar_relation=
  #     [#<MarjRecord:0x0000000126c42080
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