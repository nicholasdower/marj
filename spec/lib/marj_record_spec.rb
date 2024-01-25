# frozen_string_literal: true

require_relative '../spec_helper'

describe MarjRecord do
  describe 'implicit_order_column' do
    before do
      TestJob.perform_later.tap { MarjRecord.where(job_id: _1.job_id).update(job_id: '2') }
      Timecop.travel(1.minute)
      TestJob.perform_later.tap { MarjRecord.where(job_id: _1.job_id).update(job_id: '1') }
    end

    it 'causes jobs to be ordered by enqueued_at' do
      expect(MarjRecord.first).to have_attributes(job_id: '2')
    end
  end

  describe '.ready' do
    it 'returns jobs where scheduled_at is null' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      expect(MarjRecord.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'returns jobs where scheduled_at is in the past' do
      TestJob.set(queue: '1', wait: 1.minutes).perform_later
      Timecop.travel(2.minutes)
      expect(MarjRecord.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'does not return jobs where scheduled_at is in the future' do
      TestJob.set(queue: '1', wait: 2.minutes).perform_later
      Timecop.travel(1.minute)
      expect(MarjRecord.ready.map(&:queue_name)).to be_empty
    end

    it 'returns jobs with a priority before jobs without a priority' do
      TestJob.set(queue: '1', wait: 2.minute, priority: 1).perform_later
      TestJob.set(queue: '2', wait: 1.minute, priority: nil).perform_later
      Timecop.travel(3.minutes)
      expect(MarjRecord.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a scheduled_at before jobs without a scheduled_at' do
      TestJob.set(queue: '1', wait: 1.minute).perform_later
      TestJob.set(queue: '2').perform_later
      Timecop.travel(2.minutes)
      expect(MarjRecord.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a sooner enqueued_at before jobs with a later enqueued_at' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: '2').perform_later
      Timecop.travel(1.minute)
      expect(MarjRecord.ready.map(&:queue_name)).to eq(%w[1 2])
    end
  end

  describe '#register_callbacks' do
    context 'when callbacks already registered' do
      it 'raises' do
        job = TestJob.perform_later
        expect { MarjRecord.send(:register_callbacks, job, Marj.first) }
          .to raise_error(RuntimeError, /already registered/)
      end

      it 'does not register re-register callbacks' do
        job = TestJob.perform_later

        expect(job.singleton_class).not_to receive(:after_perform)
        expect(job.singleton_class).not_to receive(:after_discard)
        MarjRecord.send(:register_callbacks, job, Marj.first) rescue nil
      end
    end
  end

  describe '#job' do
    subject { record.job }

    let(:record) { MarjRecord.first }
    let(:job) { TestJob.perform_later }

    before { job }

    it 'returns a job instance' do
      expect(subject).to be_a(TestJob)
    end

    it 'deserializes the job data' do
      %i[job_id executions arguments queue_name priority scheduled_at].each do |field|
        expect(subject.public_send(field)).to eq(job.public_send(field))
      end
    end

    context 'when called again' do
      it 'returns the same job instance' do
        expect(record.job).to be(record.job)
      end
    end
  end
end
