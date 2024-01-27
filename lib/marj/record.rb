# frozen_string_literal: true

require 'active_job'
require 'active_record'
require_relative 'record_interface'

module Marj
  # The Marj ActiveRecord model class.
  #
  # See https://github.com/nicholasdower/marj
  class Record < ActiveRecord::Base
    include Marj::RecordInterface
    extend Marj::RecordInterface::ClassMethods # Extended explicitly to generate docs

    self.table_name = 'jobs'
  end
end
