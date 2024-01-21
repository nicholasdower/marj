# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Rails Integration' do
  it 'autoloads, enqueues, executes and deletes' do
    Bundler.with_unbundled_env do
      expect(
        system(
          <<~SHELL
            cd rails-sample &&
            bundle install > /dev/null && \
            bundle exec bin/rake db:reset > /dev/null && \
            bundle exec bin/rake db:setup > /dev/null && \
            bundle exec bin/rake marj:test
          SHELL
        )
      ).to eq(true)
    end
  end
end
