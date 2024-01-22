# frozen_string_literal: true

# Marj configuration.
class MarjConfig
  @table_name = 'jobs'

  class << self
    # The name of the database table. Defaults to "jobs".
    #
    # @return [String]
    attr_accessor :table_name
  end
end
