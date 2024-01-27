# frozen_string_literal: true

require_relative 'jobs_interface'
require_relative 'relation'

module Marj
  # Provides methods for querying, performing and discarding jobs. Returns, yields and accepts
  # +ActiveJob+ objects rather than +ActiveRecord+ objects. To query the database directly, use
  # {Marj::Record}.
  #
  # To create a custom jobs interface, see {Marj::JobsInterface}.
  module Jobs
    singleton_class.include Marj::JobsInterface

    # Returns a {Marj::Relation} for all jobs in the order they should be executed.
    #
    # @return [Marj::Relation]
    def self.all
      Marj::Relation.new(Marj::Record.ordered)
    end

    # Discards the specified job.
    #
    # @return [Integer] the number of discarded jobs
    def self.discard(job)
      all.where(job_id: job.job_id).discard_all
    end
  end
end
