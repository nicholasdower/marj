# frozen_string_literal: true

require_relative '../spec_helper'
require 'bundler'

describe 'Rails Integration' do
  it 'autoloads, enqueues, executes and discards' do
    progress = RSpec.configuration.formatters.map(&:class).include?(RSpec::Core::Formatters::ProgressFormatter)
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-rails-app &&
            bundle install > /dev/null && \
            bundle exec bin/rake db:setup > /dev/null 2> /dev/null && \
            bundle exec rspec #{progress ? '--format progress' : ''}
          SHELL
        )
      ).to eq(true)
    end
  end
end
