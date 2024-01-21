class TestJob < ActiveJob::Base
  @runs = []

  class << self
    attr_reader :runs
  end

  def perform(*args)
    args.map { eval(_1) }
  end
end
