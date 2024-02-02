# frozen_string_literal: true

# A job that can be used for testing.
class TestJob < ActiveJob::Base
  include Marj
  retry_on Exception, wait: 10.seconds, attempts: 2

  @runs = []
  @log = []

  class << self
    attr_reader :runs, :log

    def reset
      @log.clear
      @runs.clear
    end
  end

  def perform(*args)
    args.map { eval(_1) } # rubocop:disable Security/Eval
  end

  before_enqueue { |_job| TestJob.log << :before_enqueue }
  after_enqueue { |_job| TestJob.log << :after_enqueue }

  around_enqueue do |_job, block|
    TestJob.log << :around_enqueue_start
    block.call
    TestJob.log << :around_enqueue_end
  end

  before_perform { |_job| TestJob.log << :before_perform }
  after_perform { |_job| TestJob.log << :after_perform }

  around_perform do |_job, block|
    TestJob.log << :around_perform_start
    block.call
    TestJob.log << :around_perform_end
  end

  after_discard { |_job| TestJob.log << :after_discard }
end
