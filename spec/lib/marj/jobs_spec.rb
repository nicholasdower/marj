# frozen_string_literal: true

require_relative '../../spec_helper'

describe Marj::Jobs do
  describe '.all' do
    subject { Marj::Jobs.all }

    context 'when jobs exist' do
      it 'returns a Marj::Relation for all jobs' do
        job1 = TestJob.perform_later
        job2 = TestJob.perform_later
        expect(subject).to be_a(Marj::Relation)
        expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id)
      end
    end

    context 'when no jobs exist' do
      it 'returns an empty Marj::Relation' do
        expect(subject).to be_a(Marj::Relation)
        expect(subject.map(&:job_id)).to be_empty
      end
    end
  end

  describe '.where' do
    subject { Marj::Jobs.where(queue_name: 'foo') }

    context 'when jobs match' do
      it 'returns a Marj::Relation for jobs matching the specified criteria' do
        job1 = TestJob.set(queue: 'foo').perform_later
        TestJob.set(queue: 'bar').perform_later
        job3 = TestJob.set(queue: 'foo').perform_later
        expect(subject).to be_a(Marj::Relation)
        expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job3.job_id)
      end
    end

    context 'when no jobs match' do
      it 'returns an empty Marj::Relation' do
        TestJob.set(queue: 'bar').perform_later
        expect(subject).to be_a(Marj::Relation)
        expect(subject.map(&:job_id)).to be_empty
      end
    end
  end

  describe '.count' do
    context 'without a column_name or block' do
      subject { Marj::Jobs.count }

      context 'when jobs exist' do
        it 'returns a count of all jobs' do
          TestJob.perform_later
          TestJob.perform_later
          expect(subject).to eq(2)
        end
      end

      context 'when no jobs exist' do
        it 'returns zero' do
          expect(subject).to eq(0)
        end
      end
    end

    context 'with a column name' do
      subject { Marj::Jobs.count('distinct queue_name') }

      context 'when jobs exist' do
        it 'returns a count of all jobs' do
          TestJob.set(queue: 'foo').perform_later
          TestJob.set(queue: 'foo').perform_later
          TestJob.set(queue: 'bar').perform_later
          expect(subject).to eq(2)
        end
      end

      context 'when no jobs exist' do
        it 'returns zero' do
          expect(subject).to eq(0)
        end
      end
    end

    context 'with a block' do
      subject { Marj::Jobs.count { _1.queue_name == 'bar' } }

      context 'when matching jobs exist' do
        it 'returns a count of all matching jobs' do
          TestJob.set(queue: 'foo').perform_later
          TestJob.set(queue: 'bar').perform_later
          expect(subject).to eq(1)
        end
      end

      context 'when no matching jobs exist' do
        it 'returns zero' do
          expect(subject).to eq(0)
        end
      end
    end

    context 'with a column_name and a block' do
      subject { Marj::Jobs.count('foo') { _1.queue_name == 'bar' } }

      it 'raises' do
        expect { subject }.to raise_error(ArgumentError, /not supported/)
      end
    end
  end

  describe '.first' do
    subject { Marj::Jobs.first }

    it 'returns the first job by enqueued_at' do
      job1 = TestJob.perform_later
      Timecop.travel(1.second)
      TestJob.perform_later
      expect(subject.job_id).to eq(job1.job_id)
    end

    context 'when no jobs exist' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.last' do
    subject { Marj::Jobs.last }

    it 'returns the last job by enqueued_at' do
      TestJob.perform_later
      Timecop.travel(1.second)
      job2 = TestJob.perform_later
      expect(subject.job_id).to eq(job2.job_id)
    end

    context 'when no jobs exist' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '.ready' do
    it 'returns jobs where scheduled_at is null' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      expect(Marj::Jobs.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'returns jobs where scheduled_at is in the past' do
      TestJob.set(queue: '1', wait: 1.minutes).perform_later
      Timecop.travel(2.minutes)
      expect(Marj::Jobs.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'does not return jobs where scheduled_at is in the future' do
      TestJob.set(queue: '1', wait: 2.minutes).perform_later
      Timecop.travel(1.minute)
      expect(Marj::Jobs.ready.map(&:queue_name)).to be_empty
    end

    it 'returns jobs with a priority before jobs without a priority' do
      TestJob.set(queue: '1', wait: 2.minute, priority: 1).perform_later
      TestJob.set(queue: '2', wait: 1.minute, priority: nil).perform_later
      Timecop.travel(3.minutes)
      expect(Marj::Jobs.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a scheduled_at before jobs without a scheduled_at' do
      TestJob.set(queue: '1', wait: 1.minute).perform_later
      TestJob.set(queue: '2').perform_later
      Timecop.travel(2.minutes)
      expect(Marj::Jobs.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a sooner enqueued_at before jobs with a later enqueued_at' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: '2').perform_later
      Timecop.travel(1.minute)
      expect(Marj::Jobs.ready.map(&:queue_name)).to eq(%w[1 2])
    end
  end

  describe '.perform_all' do
    subject { Marj::Jobs.perform_all }

    context 'when jobs exist' do
      before do
        TestJob.perform_later('TestJob.runs << 1; "foo"')
        TestJob.perform_later('TestJob.runs << 2; "bar"')
      end

      it 'executes all jobs' do
        expect { subject }.to change { TestJob.runs.sort }.from([]).to([1, 2])
      end

      it 'removes the jobs from the queue' do
        expect { subject }.to change(Marj::Record, :count).from(2).to(0)
      end

      it 'returns the job results' do
        expect(subject).to contain_exactly(['foo'], ['bar'])
      end
    end

    context 'when no jobs exist' do
      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end

  describe '.discard_all' do
    subject { Marj::Jobs.discard_all }

    context 'when jobs exist' do
      before do
        TestJob.perform_later
        TestJob.perform_later
      end

      it 'discards all jobs' do
        expect { subject }.to change(Marj::Record, :count).from(2).to(0)
      end

      it 'returns the number of jobs discarded' do
        expect(subject).to eq(2)
      end
    end

    context 'when no jobs exist' do
      it 'returns zero' do
        expect(subject).to eq(0)
      end
    end
  end

  describe '.discard' do
    subject { Marj::Jobs.discard(job) }

    before { job }

    context 'when the job exists' do
      let(:job) { TestJob.perform_later }

      it 'discards the job' do
        expect { subject }.to change(Marj::Record, :count).from(1).to(0)
      end

      it 'returns true' do
        expect(subject).to eq(1)
      end
    end

    context 'when the job does not exist' do
      let(:job) { TestJob.new }

      it 'returns zero' do
        expect(subject).to eq(0)
      end
    end
  end
end