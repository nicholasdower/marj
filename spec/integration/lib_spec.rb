# frozen_string_literal: true

require_relative '../spec_helper'
require 'bundler'

describe 'Lib Integration' do
  it 'autoloads, enqueues, executes and deletes' do
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd sample-lib &&
            bundle install > /dev/null && \
            bundle exec ./test.rb > /dev/null
          SHELL
        )
      ).to eq(true)
    end
  end
end
