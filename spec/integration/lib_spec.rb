# frozen_string_literal: true

require_relative '../spec_helper'
require 'bundler'

describe 'Lib Integration' do
  it 'enqueues, executes and discards' do
    progress = RSpec.configuration.formatters.map(&:class).include?(RSpec::Core::Formatters::ProgressFormatter)
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-lib &&
            bundle install > /dev/null && \
            bundle exec rspec #{progress ? '--format progress' : ''}
          SHELL
        )
      ).to eq(true)
    end
  end
end
