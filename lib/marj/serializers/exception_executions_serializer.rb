# frozen_string_literal: true

module Marj
  # Contains serializers for columns.
  module Serializers
    # Serializer for the +exception_executions+ column.
    class ExceptionExecutionsSerializer
      # Returns a string representation of +exception_executions+.
      #
      # @param exception_executions [Hash, String, NilClass]
      # @return [String]
      def self.dump(exception_executions)
        case exception_executions
        when Hash
          exception_executions&.to_json
        when String, NilClass
          exception_executions
        else
          raise "invalid exception_executions: #{exception_executions}"
        end
      end

      # Converts a string representation of an +exception_executions+ hash into a Hash.
      #
      # @param exception_executions [String]
      # @return [Hash]
      def self.load(exception_executions)
        exception_executions ? JSON.parse(exception_executions) : nil
      end
    end
  end
end
