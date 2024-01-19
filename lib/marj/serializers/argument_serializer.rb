# frozen_string_literal: true

module Marj
  # Contains serializers for columns.
  module Serializers
    # Serializer for the +arguments+ column.
    class ArgumentsSerializer
      # Returns a string representation of +arguments+.
      #
      # @param arguments [Array, String, NilClass]
      # @return [String]
      def self.dump(arguments)
        case arguments
        when Array
          ActiveJob::Arguments.serialize(arguments).to_json
        when String, NilClass
          arguments
        else
          raise "invalid arguments: #{arguments}"
        end
      end

      # Converts a string representation of an +arguments+ array into a an array
      #
      # @param arguments [String]
      # @return [Array]
      def self.load(arguments)
        arguments ? ActiveJob::Arguments.deserialize(JSON.parse(arguments)) : nil
      end
    end
  end
end
