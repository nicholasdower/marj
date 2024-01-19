# frozen_string_literal: true

module Marj
  # Contains serializers for columns.
  module Serializers
    # Serializer for the +job_class+ column.
    class JobClassSerializer
      # Returns a string representation of +job_class+.
      #
      # @param job_class [Class, String, NilClass]
      # @return [String]
      def self.dump(job_class)
        case job_class
        when Class
          job_class.name
        when String, NilClass
          job_class
        else
          raise "invalid job_class: #{job_class}"
        end
      end

      # Converts a string representation of a +job_class+ into a class.
      #
      # @param job_class [String]
      # @return [Class]
      def self.load(job_class)
        job_class&.constantize
      end
    end
  end
end
