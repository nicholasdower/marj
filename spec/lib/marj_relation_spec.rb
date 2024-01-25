# frozen_string_literal: true

require_relative '../spec_helper'
require 'pp'

describe MarjRelation do
  describe '.where' do
    subject { Marj.where(priority: 1).where(queue_name: 'foo') }

    it 'returns a MarjRelation with the added criteria' do
      job1 = TestJob.set(queue: 'foo', priority: 1).perform_later
      TestJob.set(queue: 'foo', priority: 2).perform_later
      TestJob.set(queue: 'bar', priority: 1).perform_later
      job4 = TestJob.set(queue: 'foo', priority: 1).perform_later
      expect(subject).to be_a(MarjRelation)
      expect(subject.map(&:job_id)).to contain_exactly(job1.job_id, job4.job_id)
    end
  end

  describe '.first' do
    subject { Marj.where(priority: 2).first }

    it 'returns the first matching job' do
      TestJob.set(queue: 'foo', priority: 1).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'bar', priority: 2).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'baz', priority: 2).perform_later
      Timecop.travel(1.minute)
      expect(subject).to be_a(TestJob)
      expect(subject.queue_name).to eq('bar')
    end
  end

  describe '.last' do
    subject { Marj.where(priority: 2).last }

    it 'returns the last matching job' do
      TestJob.set(queue: 'foo', priority: 1).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'bar', priority: 2).perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: 'baz', priority: 2).perform_later
      Timecop.travel(1.minute)
      expect(subject).to be_a(TestJob)
      expect(subject.queue_name).to eq('baz')
    end
  end

  describe '.count' do
    subject { Marj.where(priority: 2).count }

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

  describe '.ready' do
    subject { Marj.where(priority: 2).ready }

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

  describe '.perform_all' do
    subject { Marj.where(priority: 2).perform_all }

    context 'when matching jobs exist' do
      before do
        TestJob.set(priority: 1).perform_later('TestJob.runs << 1; "foo"')
        TestJob.set(priority: 2).perform_later('TestJob.runs << 2; "bar"')
        TestJob.set(priority: 2).perform_later('TestJob.runs << 3; "baz"')
      end

      it 'executes all matching jobs' do
        expect { subject }.to change(TestJob, :runs).from([]).to([2, 3])
      end

      it 'removes the jobs from the queue' do
        expect { subject }.to change(MarjRecord, :count).from(3).to(1)
        expect(MarjRecord.first.priority).to eq(1)
      end

      it 'returns the job results' do
        expect(subject).to eq([['bar'], ['baz']])
      end
    end

    context 'when no jobs exist' do
      it 'returns an empty array' do
        expect(subject).to eq([])
      end
    end
  end

  describe '.discard_all' do
    subject { Marj.where(priority: 2).discard_all }

    context 'when matching jobs exist' do
      before do
        TestJob.set(priority: 1).perform_later
        TestJob.set(priority: 2).perform_later
        TestJob.set(priority: 2).perform_later
      end

      it 'discards all matching jobs' do
        expect { subject }.to change(MarjRecord, :count).from(3).to(1)
        expect(MarjRecord.first.priority).to eq(1)
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

  context '#pretty_print' do
    subject { PP.pp(Marj.all, StringIO.new).string }

    before { TestJob.perform_later(1) }

    it 'returns jobs representations' do
      expect(subject).to start_with('[#<TestJob:')
    end
  end
end
