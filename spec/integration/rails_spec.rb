# frozen_string_literal: true

require_relative '../spec_helper'
require 'bundler'

describe 'Rails Integration' do
  it 'autoloads, enqueues, executes and deletes' do
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-rails-app &&
            bundle install > /dev/null && \
            bundle exec bin/rake db:setup > /dev/null 2> /dev/null && \
            bundle exec bin/rake marj:test_marj
          SHELL
        )
      ).to eq(true)
    end
  end

  it 'queries with Mission Control' do
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-rails-app &&
            bundle install > /dev/null && \
            bundle exec bin/rake db:setup > /dev/null 2> /dev/null && \
            bundle exec bin/rake marj:test_mission_control_query
          SHELL
        )
      ).to eq(true)
    end
  end

  it 'retries with Mission Control' do
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-rails-app &&
            bundle install > /dev/null && \
            bundle exec bin/rake db:setup > /dev/null 2> /dev/null && \
            bundle exec bin/rake marj:test_mission_control_retry
          SHELL
        )
      ).to eq(true)
    end
  end
end
