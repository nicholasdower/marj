require_relative "boot"

require "rails"
require "active_job/railtie"
require "active_record/railtie"
require 'marj'

Bundler.require(*Rails.groups)

module RailsSample
  class Application < Rails::Application
    config.load_defaults 7.1
    config.active_job.queue_adapter = :marj
  end
end
