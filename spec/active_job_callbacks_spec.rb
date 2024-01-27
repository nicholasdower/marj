# frozen_string_literal: true

require_relative 'spec_helper'

describe 'ActiveJob Hooks' do
  before do
    ActiveJob::Callbacks.singleton_class.set_callback(:execute, :before) { TestJob.log << :execute }
  end

  after do
    ActiveJob::Callbacks.singleton_class.reset_callbacks(:execute)
  end

  context 'when the job is enqueued successfully' do
    it 'invokes all hooks' do
      TestJob.perform_later('1')
      expect(TestJob.log).to eq(%i[before_enqueue around_enqueue_start around_enqueue_end after_enqueue])
    end
  end

  context 'when the job is performed successfully' do
    it 'invokes all hooks' do
      job = TestJob.perform_later('1')
      TestJob.log.clear
      job.perform_now
      expect(TestJob.log).to eq(%i[before_perform around_perform_start around_perform_end after_perform])
    end
  end

  context 'when the job is performed successfully' do
    it 'invokes all hooks' do
      TestJob.perform_later('1')
      TestJob.log.clear
      Marj::Jobs.next.perform_now
      expect(TestJob.log).to eq(%i[before_perform around_perform_start around_perform_end after_perform])
    end
  end

  context 'when the job is executed successfully' do
    it 'invokes all hooks' do
      TestJob.perform_later('1')
      TestJob.log.clear
      ActiveJob::Base.execute(Marj::Jobs.next.serialize)
      expect(TestJob.log).to eq(%i[execute before_perform around_perform_start around_perform_end after_perform])
    end
  end

  context 'when perform_now fails and the job is successfully re-enqueued' do
    it 'invokes all hooks' do
      job = TestJob.perform_later('raise "hi"')
      TestJob.log.clear
      job.perform_now
      expect(TestJob.log).to eq(
        %i[before_perform around_perform_start before_enqueue around_enqueue_start around_enqueue_end after_enqueue]
      )
    end
  end

  context 'when perform_now fails and the job is successfully re-enqueued' do
    it 'invokes all hooks' do
      TestJob.perform_later('raise "hi"')
      TestJob.log.clear
      Marj::Jobs.next.perform_now
      expect(TestJob.log).to eq(
        %i[
          before_perform around_perform_start before_enqueue
          around_enqueue_start around_enqueue_end after_enqueue
        ]
      )
    end
  end

  context 'when execute fails and the job is successfully re-enqueued' do
    it 'invokes all hooks' do
      TestJob.perform_later('raise "hi"')
      TestJob.log.clear
      ActiveJob::Base.execute(Marj::Jobs.next.serialize)
      expect(TestJob.log).to eq(
        %i[
          execute before_perform around_perform_start before_enqueue
          around_enqueue_start around_enqueue_end after_enqueue
        ]
      )
    end
  end

  context 'when perform_now fails and the job is discarded' do
    it 'invokes all hooks' do
      job = TestJob.perform_later('raise "hi"')
      job.perform_now
      TestJob.log.clear
      job.perform_now rescue nil
      expect(TestJob.log).to eq(%i[before_perform around_perform_start after_discard])
    end
  end

  context 'when perform_now fails and the job is discarded' do
    it 'invokes all hooks' do
      TestJob.perform_later('raise "hi"')
      record = Marj::Jobs.next
      record.perform_now
      TestJob.log.clear
      record.perform_now rescue nil
      expect(TestJob.log).to eq(%i[before_perform around_perform_start after_discard])
    end
  end

  context 'when execute fails and the job is discarded' do
    it 'invokes all hooks' do
      TestJob.perform_later('raise "hi"')
      ActiveJob::Base.execute(Marj::Jobs.next.serialize)
      TestJob.log.clear
      ActiveJob::Base.execute(Marj::Jobs.next.serialize) rescue nil
      expect(TestJob.log).to eq(%i[execute before_perform around_perform_start after_discard])
    end
  end
end
