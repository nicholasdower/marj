# frozen_string_literal: true

require_relative 'marj_adapter'
require_relative 'marj_config'

Kernel.autoload(:Marj, File.expand_path('../app/models/marj.rb', __dir__))
