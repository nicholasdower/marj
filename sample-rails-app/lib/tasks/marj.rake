# frozen_string_literal: true

require 'English'
namespace :marj do
  desc 'Test Autoload'
  task test_autoload: :environment do
    loaded = false
    ActiveSupport.on_load(:active_record) { loaded = true }
    raise 'ActiveRecord loaded too soon' if loaded

    Marj.query(:count)
    raise 'ActiveRecord not loaded' unless loaded
  end
end
