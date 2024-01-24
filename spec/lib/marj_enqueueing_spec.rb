# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Marj Enqueueing' do
  describe '#perform_later' do
    context 'when a new job instance is enqueued' do
      subject { TestJob.perform_later('1') }

      it 'inserts a database record' do
        expect { subject }.to change(Marj, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(Marj.last.arguments.first).to eq('1')
      end
    end

    context 'when an updated job instance is enqueued' do
      subject { TestJob.perform_later(job) }

      let(:job) { TestJob.set(queue: 'foo').perform_later('1') }

      before { job.queue_name = 'bar' }

      it 'updates the record' do
        expect { subject }.to change { Marj.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a job instance corresponding to a deleted job is enqueued' do
      subject { TestJob.perform_later(job) }

      let(:job) { TestJob.perform_later('1') }

      before do
        job
        Marj.delete_all
      end

      it 'inserts a database record' do
        expect { subject }.to change(Marj, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(Marj.last.arguments.first).to eq('1')
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
        expect(Marj.last.arguments.first).to eq('1')
      end
    end

    context 'when an updated job instance is enqueued' do
      subject { job.enqueue }

      let(:job) { TestJob.set(queue: 'foo').perform_later('1') }

      before { job.queue_name = 'bar' }

      it 'updates the record' do
        expect { subject }.to change { Marj.last.queue_name }.from('foo').to('bar')
      end
    end

    context 'when a job instance corresponding to a deleted job is enqueued' do
      subject { job.enqueue }

      let(:job) { TestJob.perform_later('1') }

      before do
        job
        Marj.delete_all
      end

      it 'inserts a database record' do
        expect { subject }.to change(Marj, :count).from(0).to(1)
      end

      it 'persists the job arguments' do
        subject
        expect(Marj.last.arguments.first).to eq('1')
      end
    end
  end
end
