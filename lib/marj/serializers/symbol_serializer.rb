# frozen_string_literal: true

module Marj
  # Contains serializers for columns.
  module Serializers
    # Serializer for columns containing symbols.
    class SymbolSerializer
      # Returns a string representation of the specified symbol.
      #
      # @param sym [Symbol, NilClass]
      # @return [String]
      def self.dump(sym)
        sym&.to_s
      end

      # Converts the specified string into a symbol.
      #
      # @param str [String]
      # @return [Symbol]
      def self.load(str)
        str&.to_sym
      end
    end
  end
end
