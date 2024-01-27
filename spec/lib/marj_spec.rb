# frozen_string_literal: true

require_relative '../spec_helper'

describe Marj do
  describe '#to_job' do
    subject { Marj.send(:to_job, record) }

    let(:record) { Marj::Record.first }
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
  end

  describe '#register_callbacks' do
    context 'when callbacks already registered' do
      it 'raises' do
        job = TestJob.perform_later
        expect { Marj.send(:register_callbacks, job, Marj::Jobs.next) }
          .to raise_error(RuntimeError, /already registered/)
      end

      it 'does not register re-register callbacks' do
        job = TestJob.perform_later

        expect(job.singleton_class).not_to receive(:after_perform)
        expect(job.singleton_class).not_to receive(:after_discard)
        Marj.send(:register_callbacks, job, Marj::Jobs.next) rescue nil
      end
    end
  end
end
