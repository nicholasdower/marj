# frozen_string_literal: true

class TestJob < ActiveJob::Base
  retry_on Exception, wait: 10.seconds, attempts: 2

  @runs = []

  class << self
    attr_reader :runs
  end

  def perform(*args)
    args.map { eval(_1) } # rubocop:disable Security/Eval
  end
end
