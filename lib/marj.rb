# frozen_string_literal: true

require_relative 'marj_adapter'

# A minimal database-backed ActiveJob queueing backend.
#
# The {Marj} module provides the following methods:
# - +query+ - Queries enqueued jobs
# - +discard+ - Discards a job
#
# It is possible to call the above methods on the {Marj} module itself or on any class which includes it.
#
# Example usage:
#   Marj.query(:first) # Returns the first job
#   Marj.discard(job)  # Discards the specified job
#
#   class ApplicationJob < ActiveJob::Base
#     include Marj
#   end
#
#   class SomeJob < ApplicationJob;
#     def perform; end
#   end
#
#   job = ApplicationJob.query(:first) # Returns the first enqueued job
#   job = SomeJob.query(:first)        # Returns the first enqueued job with job_class SomeJob
#   ApplicationJob.discard(job)        # Discards the specified job
#   job.discard                        # Discards the job
#
# See https://github.com/nicholasdower/marj
module Marj
  # The Marj version.
  VERSION = '6.0.0.pre'

  Kernel.autoload(:Record, File.expand_path(File.join('marj', 'record.rb'), __dir__))

  # Provides the {query} and {discard} class methods.
  module ClassMethods
    # Queries enqueued jobs.
    #
    # Similar to +ActiveRecord.where+ with a few additional features.
    #
    # Example usage:
    #   query(:all)             # Delegates to Marj::Record.all
    #   query(:due)             # Delegates to Marj::Record.due
    #   query(:all, limit: 10)  # Returns a maximum of 10 jobs
    #   query(job_class: Foo)   # Returns all jobs with job_class Foo
    #
    #   query('123')            # Returns the job with id '123' or nil if no such job exists
    #   query(id: '123')        # Same as above
    #   query(job_id: '123')    # Same as above
    #
    #   query(queue: 'foo')     # Returns all jobs in the 'foo' queue
    #   query(job_queue: 'foo') # Same as above
    def query(*args, **kwargs)
      kwargs[:job_class] ||= self if self < ActiveJob::Base && name != 'ApplicationJob'
      queue_adapter.query(*args, **kwargs)
    end

    # Discards the specified job.
    #
    # @return [ActiveJob::Base] the discarded job
    def discard(job)
      queue_adapter.discard(job)
    end
  end

  # (see ClassMethods#query)
  def self.query(*args, **kwargs)
    queue_adapter.query(*args, **kwargs)
  end

  # (see ClassMethods#discard)
  def self.discard(job)
    queue_adapter.discard(job)
  end

  # Discards this job.
  #
  # @return [ActiveJob::Base] this job
  def discard
    self.class.queue_adapter.discard(self)
  end

  def self.included(clazz)
    clazz.extend(ClassMethods)
  end
  private_class_method :included

  def self.queue_adapter
    ActiveJob::Base.queue_adapter
  end
  private_class_method :queue_adapter
end
