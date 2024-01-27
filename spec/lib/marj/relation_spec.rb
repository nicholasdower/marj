# frozen_string_literal: true

require_relative '../../spec_helper'
require 'pp'

describe Marj::Relation do
  describe '#where' do
    subject { Marj::Jobs.where(priority: 1).where(queue_name: 'foo') }

    it 'returns a Marj::Relation with the added criteria' do
      job1 = TestJob.set(queue: 'foo', priority: 1).perform_later
      TestJob.set(queue: 'foo', priority: 2).perform_later
      TestJob.set(queue: 'bar', priority: 1).perform_later
      job4 = TestJob.set(queue: 'foo', priority: 1).perform_later
      expect(subject).to be_a(Marj::Relation)
      expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job4.job_id)
    end
  end

  describe '#next' do
    before do
      TestJob.set(queue: 'foo', priority: 1).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'bar', priority: 2).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'baz', priority: 2).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'moo', priority: 2).perform_later
      Timecop.travel(1.minute)
    end

    context 'without limit' do
      subject { Marj::Jobs.where(priority: 2).next }

      it 'returns the next matching job' do
        expect(subject).to be_a(TestJob)
        expect(subject.queue_name).to eq('bar')
      end
    end

    context 'with limit' do
      subject { Marj::Jobs.where(priority: 2).next(2) }

      it 'returns the next N matching jobs' do
        expect(subject.map(&:class)).to eq([TestJob, TestJob])
        expect(subject.map(&:queue_name)).to eq(%w[bar baz])
      end
    end
  end

  describe '#count' do
    subject { Marj::Jobs.where(priority: 2).count }

    it 'returns the number of matching job' do
      TestJob.set(queue: 'foo', priority: 1).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'bar', priority: 2).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'baz', priority: 2).perform_later
      Timecop.travel(1.minute)
      expect(subject).to eq(2)
    end
  end

  describe '#queue' do
    context 'when one queue is specified' do
      subject { Marj::Jobs.where(priority: 1).queue('foo') }

      it 'returns matching jobs' do
        job1 = TestJob.set(priority: 1, queue: 'foo').perform_later
        job2 = TestJob.set(priority: 1, queue: 'foo').perform_later
        TestJob.set(priority: 2, queue: 'foo').perform_later
        TestJob.set(priority: 1, queue: 'bar').perform_later
        expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id)
      end
    end

    context 'when one queue is specified' do
      subject { Marj::Jobs.where(priority: 1).queue('foo', 'bar') }

      it 'returns jobs with the specified queue_name' do
        job1 = TestJob.set(priority: 1, queue: 'foo').perform_later
        job2 = TestJob.set(priority: 1, queue: 'foo').perform_later
        TestJob.set(priority: 2, queue: 'foo').perform_later
        job4 = TestJob.set(priority: 1, queue: 'bar').perform_later
        TestJob.set(priority: 2, queue: 'bar').perform_later
        TestJob.set(priority: 1, queue: 'baz').perform_later
        TestJob.set(priority: 2, queue: 'baz').perform_later
        expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job2.job_id, job4.job_id)
      end
    end
  end

  describe '#due' do
    subject { Marj::Jobs.where(priority: 2).due }

    it 'returns the matching job' do
      TestJob.set(priority: 1).perform_later
      job2 = TestJob.set(priority: 2).perform_later
      TestJob.set(wait: 1.minutes, priority: 1).perform_later
      job4 = TestJob.set(wait: 1.minutes, priority: 2).perform_later
      TestJob.set(wait: 5.minutes, priority: 2).perform_later
      TestJob.set(wait: 5.minutes, priority: 2).perform_later
      Timecop.travel(2.minute)
      expect(subject.map(&:job_id)).to eq([job4.job_id, job2.job_id])
    end
  end

  describe '#perform_all' do
    subject { Marj::Jobs.where(priority: 2).perform_all }

    context 'when matching jobs exist' do
      context 'without batch_size' do
        before do
          TestJob.set(priority: 1).perform_later('TestJob.runs << 1; "foo"')
          TestJob.set(priority: 2).perform_later('TestJob.runs << 2; "bar"')
          TestJob.set(priority: 2).perform_later('TestJob.runs << 3; "baz"')
        end

        it 'executes all matching jobs' do
          expect { subject }.to change { TestJob.runs.sort }.from([]).to([2, 3])
        end

        it 'removes the jobs from the queue' do
          expect { subject }.to change(Marj::Record, :count).from(3).to(1)
          expect(Marj::Record.first.priority).to eq(1)
        end

        it 'returns the job results' do
          expect(subject).to contain_exactly(['bar'], ['baz'])
        end
      end

      context 'with batch_size' do
        subject { Marj::Jobs.where(priority: 2).perform_all(batch_size: 2) }

        let(:ar_relation) { instance_double(ActiveRecord::Relation) }

        before do
          TestJob.set(priority: 2).perform_later('TestJob.runs << 1; "foo"')
          Timecop.travel(1.minute)
          TestJob.set(priority: 2).perform_later('TestJob.runs << 2; "bar"')
          Timecop.travel(1.minute)
          TestJob.set(priority: 2).perform_later('TestJob.runs << 3; "bar"')
          Timecop.travel(1.minute)
          TestJob.set(priority: 1).perform_later('TestJob.runs << 4; "bar"')

          allow(ar_relation).to receive(:where).and_return(ar_relation)
          allow(ar_relation).to receive(:limit).and_return(Marj::Record.first(2), [Marj::Record.third], [])
          allow(Marj::Record).to receive(:ordered).and_return(ar_relation)
        end

        it 'retrieves jobs in batches' do
          expect(ar_relation).to receive(:limit).exactly(3).times
          expect { subject }.to change { TestJob.runs.sort }.from([]).to([1, 2, 3])
        end
      end
    end

    context 'when no jobs exist' do
      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end

  describe '#discard_all' do
    subject { Marj::Jobs.where(priority: 2).discard_all }

    context 'when matching jobs exist' do
      before do
        TestJob.set(priority: 1).perform_later
        TestJob.set(priority: 2).perform_later
        TestJob.set(priority: 2).perform_later
      end

      it 'discards all matching jobs' do
        expect { subject }.to change(Marj::Record, :count).from(3).to(1)
        expect(Marj::Record.first.priority).to eq(1)
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

  context 'Enumerable' do
    subject { Marj::Jobs.where(priority: 2).each { TestJob.runs << _1 } }

    it 'yields job objects' do
      TestJob.set(priority: 2, queue: 'foo').perform_later
      TestJob.set(priority: 2, queue: 'bar').perform_later
      TestJob.set(priority: 1, queue: 'baz').perform_later
      expect { subject }.to change { TestJob.runs.size }.from(0).to(2)
      expect(TestJob.runs.map(&:class)).to contain_exactly(TestJob, TestJob)
      expect(TestJob.runs.map(&:queue_name)).to contain_exactly('foo', 'bar')
    end
  end

  describe '#pretty_print' do
    subject { PP.pp(Marj::Jobs.all, StringIO.new).string }

    before { TestJob.perform_later(1) }

    it 'returns jobs representations' do
      expect(subject).to start_with('[#<TestJob:')
    end
  end
end
