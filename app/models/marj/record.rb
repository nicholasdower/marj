# frozen_string_literal: true

# ActiveRecord model for jobs.
module Marj
  class Record < ActiveRecord::Base
    self.table_name = 'jobs'
  end
end
