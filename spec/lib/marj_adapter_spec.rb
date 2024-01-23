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
      expect(Marj.last.scheduled_at.to_i).to eq(timestamp)
    end

    context 'when timestamp is nil' do
      let(:timestamp) { nil }

      it 'does not set scheduled_at' do
        subject
        expect(job.scheduled_at).to be_nil
      end

      it 'does not persist scheduled_at' do
        subject
        expect(Marj.last.scheduled_at).to be_nil
      end
    end

    context 'when the job already exists' do
      before do
        job.enqueue
        job.executions = 99
      end

      it 'updates the record' do
        subject
        expect(Marj.last.executions).to eq(99)
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
      expect(Marj.last.scheduled_at).to be_nil
    end

    it 'registers callbacks' do
      subject
      expect { job.perform_now }.to change(Marj, :count).from(1).to(0)
    end

    it 'registers callbacks' do
      subject
      expect { job.perform_now }.to change(Marj, :count).from(1).to(0)
    end

    context 'when the job already exists' do
      before do
        job.enqueue
        job.executions = 99
      end

      it 'updates the record' do
        subject
        expect(Marj.last.executions).to eq(99)
      end
    end
  end
end
