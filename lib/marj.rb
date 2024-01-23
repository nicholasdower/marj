# frozen_string_literal: true

# See https://github.com/nicholasdower/marj

require_relative 'marj_adapter'
require_relative 'marj_config'

Kernel.autoload(:Marj, File.expand_path('marj_record.rb', __dir__))
