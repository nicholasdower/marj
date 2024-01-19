# frozen_string_literal: true

require_relative 'marj/marj_adapter'

# Marj is an ActiveJob queueing backend.
module Marj
  class << self
    private

    # Enqueues a job.
    #
    # @param job [ActiveJob::Base] the job to enqueue
    # @param timestamp [Numeric, NilClass] optional number of seconds since Unix epoch at which to execute the job
    def enqueue(job, timestamp = nil)
      job.scheduled_at = timestamp ? Time.at(timestamp).utc : nil

      job.enqueued_at = Time.now.utc.to_time
      record_attributes = record_attributes(job)
      record_attributes[:state] = :enqueued
      if (record = record_class.find_by(job_id: job.job_id))
        record.update!(record_attributes)
      else
        record = record_class.create!(record_attributes)
      end
      from(record, job)

      job
    end

    # Returns a job object for the specified database record. If a job is specified, it is updated from the record.
    #
    # @param record [ActiveRecord::Base]
    # @param job [ActiveJob::Base]
    # @return [ActiveJob::Base]
    def from(record, job = nil)
      raise "expected #{record_class}, found #{record.class}" unless record.is_a?(record_class)
      raise "expected #{record.job_class}, found #{job.class}" if job && job.class != record.job_class

      job ||= record.job_class.new
      raise "expected ActiveJob::Base, found #{job.class}" unless job.is_a?(ActiveJob::Base)

      register_callbacks(job)
      job.deserialize(job_data(record))

      # ActiveJob deserializes arguments on demand when a job is performed. Until then they are empty. That's strange.
      # Instead, deserialize them now. Also, clear `serialized_arguments` to prevent ActiveJob from overwriting changes
      # to arguments when serializing later.
      job.arguments = record.arguments
      job.serialized_arguments = nil

      job.successfully_enqueued = !job.enqueued_at.nil?

      job
    end

    # Returns database record attributes for the specified job.
    #
    # @param job [ActiveJob::Base]
    # @return [Hash]
    def record_attributes(job)
      serialized = job.serialize
      serialized.delete('provider_job_id')
      serialized['arguments'] = job.arguments
      serialized['job_class'] = job.class

      # ActiveJob::Base#serialize always returns Time.now.utc.iso8601(9) for enqueued_at.
      serialized['enqueued_at'] = job.enqueued_at&.utc

      # ActiveJob::Base#serialize always returns I18n.locale.to_s for locale.
      serialized['locale'] = job.locale || serialized['locale']

      serialized.symbolize_keys
    end

    # Returns serialized job data for the specified database record.
    #
    # @param record [ActiveRecord::Base]
    # @return [Hash]
    def job_data(record)
      job_data = record.attributes
      # ActiveJob expects job_data to contain serialized arguments (The result of ActiveJob::Arguments.serialize). The
      # database contains a JSON representation of this array so we simply need to parse the JSON. We cannot use
      # record.arguments directly since Marj::ArgumentsSerializer will be applied and the the array will no
      # longer be serialized.
      job_data['arguments'] = JSON.parse(record.read_attribute_before_type_cast(:arguments))
      job_data['enqueued_at'] = job_data['enqueued_at'].iso8601 if job_data['enqueued_at']
      job_data['scheduled_at'] = job_data['scheduled_at']&.iso8601 if job_data['scheduled_at']
      job_data
    end

    # Lazily loads and returns {Marj::Record}.
    #
    # @return [Marj::Record]
    def record_class
      require_relative 'marj/record'
      Marj::Record
    end

    # Registers job callbacks.
    #
    # @param job [ActiveJob::Base]
    # @return [NilClass]
    def register_callbacks(job)
      return if job.singleton_class.include?(Marj)

      job.singleton_class.before_perform do |j|
        # Setting successfully_enqueued to false in order to detect when a job is re-enqueued during perform.
        j.successfully_enqueued = false
      end

      job.singleton_class.after_perform do |j|
        unless j.successfully_enqueued?
          j.scheduled_at = nil
          j.enqueued_at = nil
          Marj.send(:record_class).where(job_id: j.job_id).delete_all
        end
      end

      job.singleton_class.after_discard do |j, _exception|
        j.scheduled_at = nil
        j.enqueued_at = nil
        Marj.send(:record_class).where(job_id: j.job_id).delete_all
      end

      job.singleton_class.include(Marj)
      nil
    end
  end
end
