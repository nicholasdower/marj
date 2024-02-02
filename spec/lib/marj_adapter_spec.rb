# frozen_string_literal: true

require_relative '../spec_helper'

describe MarjAdapter do
  describe '#enqueue_at' do
    subject { MarjAdapter.new.enqueue_at(job, timestamp) }

    let(:job) { TestJob.new }
    let(:timestamp) { Time.now.to_i }

    it 'sets scheduled_at' do
      subject
      expect(job.scheduled_at.to_i).to eq(timestamp)
    end

    it 'persists scheduled_at' do
      subject
      expect(Marj::Record.first.scheduled_at.to_i).to eq(timestamp)
    end

    context 'when timestamp is nil' do
      let(:timestamp) { nil }

      it 'does not set scheduled_at' do
        subject
        expect(job.scheduled_at).to be_nil
      end

      it 'does not persist scheduled_at' do
        subject
        expect(Marj::Record.first.scheduled_at).to be_nil
      end
    end

    context 'when the job already exists' do
      before do
        job.enqueue
        job.executions = 99
      end

      it 'updates the record' do
        subject
        expect(Marj::Record.first.executions).to eq(99)
      end
    end
  end

  describe '#enqueue' do
    subject { MarjAdapter.new.enqueue(job) }

    let(:job) { TestJob.new }

    it 'does not set scheduled_at' do
      subject
      expect(job.scheduled_at).to be_nil
    end

    it 'does not persist scheduled_at' do
      subject
      expect(Marj::Record.first.scheduled_at).to be_nil
    end

    it 'registers callbacks' do
      subject
      expect { job.perform_now }.to change(Marj::Record, :count).from(1).to(0)
    end

    it 'registers callbacks' do
      subject
      expect { job.perform_now }.to change(Marj::Record, :count).from(1).to(0)
    end

    context 'when the job already exists' do
      before do
        job.enqueue
        job.executions = 99
      end

      it 'updates the record' do
        subject
        expect(Marj::Record.first.executions).to eq(99)
      end
    end
  end

  describe '#query' do
    let(:adapter) { described_class.new }

    it 'queries all jobs' do
      job1 = TestJob.perform_later
      job2 = TestJob.perform_later
      expect(adapter.query(:all).map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id)
    end

    it 'returns jobs in due order by default' do
      job1 = TestJob.set(wait: 1.minute).perform_later
      Timecop.travel(1.second)
      job2 = TestJob.set(wait: 10.minute).perform_later
      Timecop.travel(1.second)
      job3 = TestJob.set(wait: 30.seconds).perform_later
      Timecop.travel(1.minute)
      expect(adapter.query(:all).map(&:job_id)).to eq([job3.job_id, job1.job_id, job2.job_id])
    end

    it 'queries due jobs' do
      job1 = TestJob.perform_later
      Timecop.travel(1.minute)
      job2 = TestJob.set(wait: 30.seconds).perform_later
      Timecop.travel(1.minute)
      TestJob.set(wait: 1.minute).perform_later
      expect(adapter.query(:due).map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id)
    end

    it 'queries jobs with where' do
      job1 = TestJob.set(priority: 1).perform_later
      TestJob.set(priority: 2).perform_later
      expect(adapter.query(priority: 1).map(&:job_id)).to contain_exactly(job1.job_id)
    end

    it 'queries job count' do
      TestJob.perform_later
      TestJob.perform_later
      expect(adapter.query(:count)).to eq(2)
    end

    it 'limits results' do
      job1 = TestJob.perform_later
      Timecop.travel(1.minute)
      job2 = TestJob.perform_later
      Timecop.travel(1.minute)
      TestJob.perform_later
      expect(adapter.query(:all, limit: 2).map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id)
    end

    it 'queries by queue_name' do
      job1 = TestJob.set(queue: 'foo').perform_later
      TestJob.set(queue: 'bar').perform_later
      job3 = TestJob.set(queue: 'foo').perform_later
      expect(adapter.query(queue_name: 'foo').map(&:job_id)).to contain_exactly(job1.job_id, job3.job_id)
    end

    it 'queries by :job_id' do
      job1 = TestJob.perform_later
      TestJob.perform_later
      expect(adapter.query(job_id: job1.job_id).job_id).to eq(job1.job_id)
    end

    it 'queries by :id' do
      job1 = TestJob.perform_later
      TestJob.perform_later
      expect(adapter.query(id: job1.job_id).job_id).to eq(job1.job_id)
    end

    it 'returns nil when job not found by id' do
      job1 = TestJob.new
      TestJob.perform_later
      expect(adapter.query(id: job1.job_id)).to be_nil
    end

    it 'queries by job_id when only an id is provided' do
      job1 = TestJob.perform_later
      TestJob.perform_later
      expect(adapter.query(job1.job_id).job_id).to eq(job1.job_id)
    end

    it 'orders results by the specified criteria' do
      job1 = TestJob.set(queue: 'c').perform_later
      Timecop.travel(1.minute)
      job2 = TestJob.set(queue: 'a').perform_later
      Timecop.travel(1.minute)
      job3 = TestJob.set(queue: 'b').perform_later
      expect(adapter.query(order: :queue_name).map(&:job_id)).to eq([job2.job_id, job3.job_id, job1.job_id])
    end
  end

  describe '#discard' do
    let(:adapter) { described_class.new }

    context 'callbacks' do
      it 'executes after_discard callbacks' do
        stub_const('SomeJob', Class.new(TestJob))
        SomeJob.after_discard { TestJob.runs << 'discarded' }
        job = SomeJob.perform_later
        expect { adapter.discard(job) }.to change(TestJob, :runs).from([]).to(['discarded'])
      end

      it 'raises when the only after_discard callback raises' do
        stub_const('SomeJob', Class.new(TestJob))
        SomeJob.after_discard { raise 'hi' }
        job = SomeJob.perform_later
        expect { adapter.discard(job) }.to raise_error(StandardError, 'hi')
      end

      it 'raises when multiple after_discard callbacks raise' do
        stub_const('SomeJob', Class.new(TestJob))
        SomeJob.after_discard { TestJob.runs << 'discarded 1' }
        SomeJob.after_discard { raise 'hi' }
        SomeJob.after_discard { raise 'bye' }
        job = SomeJob.perform_later
        expect { adapter.discard(job) }.to raise_error(StandardError, 'bye')
      end
    end

    context 'when the job was ready from the database' do
      it 'discards the job' do
        job = TestJob.perform_later
        expect { adapter.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
      end

      it 'returns the job' do
        job = TestJob.perform_later
        Marj::Record.delete_all
        expect(adapter.discard(job)).to be_a(TestJob)
        expect(adapter.discard(job).job_id).to eq(job.job_id)
      end
    end

    context 'when the job was only initialized' do
      it 'discards the job' do
        original_job = TestJob.perform_later
        job = TestJob.new
        job.deserialize(original_job.serialize)
        expect { adapter.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
      end

      context 'when the record does not exist' do
        it 'returns the job' do
          original_job = TestJob.perform_later
          job = TestJob.new
          job.deserialize(original_job.serialize)
          Marj::Record.delete_all
          expect(adapter.discard(job)).to be_a(TestJob)
          expect(adapter.discard(job).job_id).to eq(job.job_id)
        end
      end
    end
  end
end
