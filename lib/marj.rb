# frozen_string_literal: true

require_relative 'marj_adapter'

# A minimal database-backed ActiveJob queueing backend.
#
# The {Marj} module provides the following methods:
# - +query+ - Queries enqueued jobs
# - +discard+ - Discards a job, by default by executing after_discard callbacks and delegating to delete
# - +delete+ - Deletes a job
#
# It is possible to call the above methods on the {Marj} module itself or on any class which includes it.
#
# Example usage:
#   Marj.query(:first) # Returns the first job
#   Marj.discard(job)  # Discards the specified job
#   Marj.delete(job)  # Deletes the specified job
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
#   ApplicationJob.delete(job)         # Deletes the specified job
#   job.discard                        # Discards the job
#   job.delete                         # Deletes the job
#
# See https://github.com/nicholasdower/marj
module Marj
  # The Marj version.
  VERSION = '7.0.0.pre'

  Kernel.autoload(:Record, File.expand_path(File.join('marj', 'record.rb'), __dir__))

  # Provides the {query} and {discard} class methods.
  module ClassMethods
    # Queries enqueued jobs. Similar to +ActiveRecord.where+ with a few additional features:
    # - Symbol arguments are treated as +ActiveRecord+ scopes.
    # - If only a job ID is specified, the corresponding job is returned.
    # - If +:limit+ is specified, the maximum number of jobs is limited.
    # - If +:order+ is specified, the jobs are ordered by the given attribute.
    #
    # By default jobs are ordered by when they should be executed.
    #
    # Example usage:
    #   query                       # Returns all jobs
    #   query(:all)                 # Returns all jobs
    #   query(:due)                 # Returns jobs which are due to be executed
    #   query(:due, limit: 10)      # Returns at most 10 jobs which are due to be executed
    #   query(job_class: Foo)       # Returns all jobs with job_class Foo
    #   query(:due, job_class: Foo) # Returns jobs which are due to be executed with job_class Foo
    #   query(queue_name: 'foo')    # Returns all jobs in the 'foo' queue
    #   query(job_id: '123')        # Returns the job with job_id '123' or nil if no such job exists
    #   query('123')                # Returns the job with job_id '123' or nil if no such job exists
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

    # Deletes the record associated with the specified job.
    #
    # @return [ActiveJob::Base] the deleted job
    def delete(job)
      queue_adapter.delete(job)
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

  # (see ClassMethods#delete)
  def self.delete(job)
    queue_adapter.delete(job)
  end

  # Deletes this job.
  #
  # @return [ActiveJob::Base] this job
  def discard
    self.class.queue_adapter.discard(self)
  end

  # Deletes the record associated with this job.
  #
  # @return [ActiveJob::Base] this job
  def delete
    self.class.queue_adapter.delete(self)
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

# :nocov:
if defined?(Rails)
  begin
    require 'mission_control/jobs'
    require_relative 'marj/mission_control'
    MarjAdapter.include(Marj::MissionControl)
  rescue LoadError
    # ignore
  end
end
# :nocov:
