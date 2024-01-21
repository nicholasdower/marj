# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'Marj Worker' do
  describe '.work_off' do
    subject { Marj.work_off }

    it 'executes all available jobs' do
      TestJob.perform_later('TestJob.runs << 1')
      Timecop.travel(1.minute)
      TestJob.perform_later('TestJob.runs << 2')
      Timecop.travel(1.minute)

      expect(Marj.count).to eq(2)
      expect(TestJob.runs).to eq([])

      subject

      expect(Marj.count).to eq(0)
      expect(TestJob.runs).to eq([1, 2])
    end

    it 'does not execute jobs which are not available' do
      TestJob.perform_later('TestJob.runs << 1')
      Timecop.travel(1.minute)
      TestJob.set(wait: 2.minutes).perform_later('TestJob.runs << 2')
      Timecop.travel(1.minute)

      expect(Marj.count).to eq(2)
      expect(TestJob.runs).to eq([])

      subject

      expect(Marj.count).to eq(1)
      expect(TestJob.runs).to eq([1])
    end

    it 'does not raise when a job fails for an expected reason' do
      TestJob.perform_later('raise "hi"')
      Timecop.travel(1.minute)
      TestJob.perform_later('TestJob.runs << 2')
      Timecop.travel(1.minute)

      expect(Marj.count).to eq(2)
      expect(TestJob.runs).to eq([])

      subject

      expect(Marj.count).to eq(1)
      expect(TestJob.runs).to eq([2])
    end

    it 'raises when a job fails for an unexpected reason' do
      TestJob.perform_later('raise "hi"')
      Timecop.travel(1.minute)
      TestJob.perform_later('TestJob.runs << 2')
      Timecop.travel(1.minute)

      expect(Marj.count).to eq(2)
      expect(TestJob.runs).to eq([])

      allow(ActiveJob::Base.queue_adapter).to receive(:enqueue_at) { raise 'hi' }
      expect { subject }.to raise_error(StandardError, 'hi')
      expect(Marj.count).to eq(2)
      expect(TestJob.runs).to eq([])
    end
  end
end
