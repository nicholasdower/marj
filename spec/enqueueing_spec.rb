# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Enqueueing' do
  describe '#perform_later' do
    context 'when a new job instance is enqueued' do
      subject { TestJob.perform_later('1') }

      it 'inserts a database record' do
        expect { subject }.to change(MarjRecord, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(MarjRecord.last.arguments.first).to eq('1')
      end
    end

    context 'when an existing, updated job instance which references an existing record is enqueued' do
      subject { TestJob.perform_later(job) }

      let(:job) { TestJob.set(queue: 'foo').perform_later('1') }

      before { job.queue_name = 'bar' }

      it 'updates the record' do
        expect { subject }.to change { MarjRecord.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a new, updated job instance which references an existing record is enqueued' do
      subject { TestJob.perform_later(new_job) }

      let(:old_job) { TestJob.set(queue: 'foo').perform_later('1') }
      let(:new_job) { TestJob.new }

      before { new_job.deserialize(old_job.serialize.merge('queue_name' => 'bar')) }

      it 'updates the record' do
        expect { subject }.to change { MarjRecord.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a job instance corresponding to a deleted job is enqueued' do
      subject { TestJob.perform_later(job) }

      let(:job) { TestJob.perform_later('1') }

      before do
        job
        MarjRecord.delete_all
      end

      it 'inserts a database record' do
        expect { subject }.to change(MarjRecord, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(MarjRecord.last.arguments.first).to eq('1')
      end
    end
  end

  describe '#enqueue' do
    context 'when a new job instance is enqueued' do
      subject { TestJob.new('1').enqueue }

      it 'inserts a database record' do
        expect { subject }.to change(Marj, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(MarjRecord.last.arguments.first).to eq('1')
      end
    end

    context 'when an existing, updated job instance which references an existing record is enqueued' do
      subject { job.enqueue }

      let(:job) { TestJob.set(queue: 'foo').perform_later('1') }

      before { job.queue_name = 'bar' }

      it 'updates the record' do
        expect { subject }.to change { MarjRecord.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a new, updated job instance which references an existing record is enqueued' do
      subject { new_job.enqueue }

      let(:old_job) { TestJob.set(queue: 'foo').perform_later('1') }
      let(:new_job) { TestJob.new }

      before { new_job.deserialize(old_job.serialize.merge('queue_name' => 'bar')) }

      it 'updates the record' do
        expect { subject }.to change { MarjRecord.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a job instance corresponding to a deleted job is enqueued' do
      subject { job.enqueue }

      let(:job) { TestJob.perform_later('1') }

      before do
        job
        MarjRecord.delete_all
      end

      it 'inserts a database record' do
        expect { subject }.to change(MarjRecord, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(MarjRecord.last.arguments.first).to eq('1')
      end
    end
  end
end