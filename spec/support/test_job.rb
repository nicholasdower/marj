# frozen_string_literal: true

# A job that can be used for testing.
class TestJob < ActiveJob::Base
  retry_on Exception, wait: 10.seconds, attempts: 2

  def perform(expr)
    eval(expr) # rubocop:disable Security/Eval
  end
end
