# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'Marj Query' do
  describe 'implicit_order_column' do
    before do
      TestJob.perform_later.tap { Marj.where(job_id: _1.job_id).update(job_id: '2') }
      Timecop.travel(1.minute)
      TestJob.perform_later.tap { Marj.where(job_id: _1.job_id).update(job_id: '1') }
    end

    it 'causes jobs to be ordered by enqueued_at' do
      expect(Marj.first).to have_attributes(job_id: '2')
    end
  end

  describe '.queues' do
    subject { Marj.queue(*queues) }

    before do
      TestJob.set(queue: 'foo').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'bar').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'baz').perform_later
      Timecop.travel(1.minute)
    end

    let(:queues) { %w[foo bar] }

    it 'returns jobs in the specified queues' do
      expect(subject.count).to eq(2)
      expect(subject.map(&:queue_name)).to contain_exactly(*queues)
    end
  end

  describe '.available' do
    it 'returns jobs where scheduled_at is null' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      expect(Marj.available.map(&:queue_name)).to eq(['1'])
    end

    it 'returns jobs where scheduled_at is in the past' do
      TestJob.set(queue: '1', wait: 1.minutes).perform_later
      Timecop.travel(2.minutes)
      expect(Marj.available.map(&:queue_name)).to eq(['1'])
    end

    it 'does not return jobs where scheduled_at is in the future' do
      TestJob.set(queue: '1', wait: 2.minutes).perform_later
      Timecop.travel(1.minute)
      expect(Marj.available.map(&:queue_name)).to be_empty
    end

    it 'returns jobs with a priority before jobs without a priority' do
      TestJob.set(queue: '1', wait: 2.minute, priority: 1).perform_later
      TestJob.set(queue: '2', wait: 1.minute, priority: nil).perform_later
      Timecop.travel(3.minutes)
      expect(Marj.available.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a scheduled_at before jobs without a scheduled_at' do
      TestJob.set(queue: '1', wait: 1.minute).perform_later
      TestJob.set(queue: '2').perform_later
      Timecop.travel(2.minutes)
      expect(Marj.available.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a sooner enqueued_at before jobs with a later enqueued_at' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: '2').perform_later
      Timecop.travel(1.minute)
      expect(Marj.available.map(&:queue_name)).to eq(%w[1 2])
    end
  end
end
