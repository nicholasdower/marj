# frozen_string_literal: true

require_relative 'boot'

require 'rails'
require 'action_controller/railtie'
require 'active_job/railtie'
require 'active_record/railtie'

Bundler.require(*Rails.groups)

# https://github.com/basecamp/mission_control-jobs/issues/42
require 'irb'

module RailsSample
  class Application < Rails::Application
    config.load_defaults 7.1
    config.active_job.queue_adapter = :marj
    config.eager_load = false

    console do
      MissionControl::Jobs::Current.server = MissionControl::Jobs::Server.from_global_id('railssample:marj')
    end
  end
end
