# frozen_string_literal: true

require_relative 'marj/version'
require_relative 'marj/marj_adapter'

# Marj is an ActiveJob queueing backend.
module Marj
  # Enqueue a job.
  #
  # @param job [ActiveJob::Base] the job to enqueue
  # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
  def self.enqueue(job, timestamp = nil)
    puts "#{job} #{timestamp}"
  end
end
