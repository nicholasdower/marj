# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Retain Discarded' do
  before do
    ActiveJob::Base.queue_adapter = MarjAdapter.new(discard: proc { _1.enqueue(queue: 'discarded') })
  end

  after do
    ActiveJob::Base.queue_adapter = :marj
  end

  describe '#discard' do
    it 'moves job to discarded queue' do
      job = TestJob.perform_later('1')
      expect(Marj::Record.count).to eq(1)
      expect(Marj::Record.where(queue_name: 'default').count).to eq(1)
      expect(Marj::Record.where(queue_name: 'discarded').count).to eq(0)
      job.discard
      expect(Marj::Record.where(queue_name: 'default').count).to eq(0)
      expect(Marj::Record.where(queue_name: 'discarded').count).to eq(1)
    end

    it 'invokes discard callbacks' do
      runs = []
      TestJob.after_discard { runs << 'discarded' }
      job = TestJob.perform_later('1')
      expect { job.discard }.to change { runs }.from([]).to(['discarded'])
    end
  end

  describe '#perform_now' do
    let(:job) { TestJob.perform_later('raise "hi"') }
    let(:callbacks) { [] }

    before do
      local_callbacks = callbacks
      TestJob.after_discard { local_callbacks << 'discarded' }
      job.perform_now
    end

    it 'moves job to discarded queue on non-retryable failure' do
      expect(Marj::Record.count).to eq(1)
      expect(Marj::Record.where(queue_name: 'default').count).to eq(1)
      expect(Marj::Record.where(queue_name: 'discarded').count).to eq(0)
      job.perform_now rescue nil
      expect(Marj::Record.where(queue_name: 'default').count).to eq(0)
      expect(Marj::Record.where(queue_name: 'discarded').count).to eq(1)
    end

    it 'invokes discard callbacks' do
      expect { job.perform_now rescue nil }.to change { callbacks }.from([]).to(['discarded'])
    end

    it 'raises' do
      expect { job.perform_now }.to raise_error(StandardError, 'hi')
    end
  end
end
