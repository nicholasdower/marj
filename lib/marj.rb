# frozen_string_literal: true

require_relative 'marj_adapter'
require_relative 'marj_relation'

Kernel.autoload(:MarjRecord, File.expand_path('marj_record.rb', __dir__))

# The simplest database-backed ActiveJob queueing backend.
#
# See https://github.com/nicholasdower/marj
class Marj
  # The Marj version.
  VERSION = '3.0.0.pre'

  @table_name = 'jobs'

  class << self
    # The name of the database table. Defaults to "jobs".
    #
    # @return [String]
    attr_accessor :table_name

    # Returns a {MarjRelation} for all jobs.
    #
    # @return [MarjRelation]
    def all
      MarjRelation.new(MarjRecord.all)
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

    # Returns a {MarjRelation} for jobs matching the specified criteria.
    #
    # @param args [Array]
    # @return [MarjRelation]
    def where(*args)
      all.where(*args)
    end

    # Returns a {MarjRelation} for enqueued jobs with a +scheduled_at+ that is either +null+ or in the past. Jobs are
    # ordered by +priority+ (+null+ last), then +scheduled_at+ (+null+ last), then +enqueued_at+.
    #
    # @return [MarjRelation]
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
      MarjRecord.where(job_id: job.job_id).delete_all
    end
  end
end
