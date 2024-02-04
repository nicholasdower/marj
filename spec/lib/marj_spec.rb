# frozen_string_literal: true

require_relative '../spec_helper'

describe Marj do
  describe '.query' do
    it 'queries' do
      job = TestJob.perform_later
      expect(Marj.query(:first).job_id).to eq(job.job_id)
    end
  end

  describe '.discard' do
    it 'discards' do
      job = TestJob.perform_later
      expect { Marj.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
    end

    it 'invokes callbacks' do
      job = TestJob.perform_later
      callbacks = []
      job.singleton_class.after_discard { callbacks << 'discarded' }
      expect { Marj.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
    end
  end

  describe '.delete' do
    it 'deletes' do
      job = TestJob.perform_later
      expect { Marj.delete(job) }.to change(Marj::Record, :count).from(1).to(0)
    end
  end

  describe 'Job.discard' do
    it 'discards' do
      job = TestJob.perform_later
      expect { TestJob.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
    end

    it 'invokes callbacks' do
      job = TestJob.perform_later
      callbacks = []
      job.singleton_class.after_discard { callbacks << 'discarded' }
      expect { TestJob.discard(job) }.to change(Marj::Record, :count).from(1).to(0)
    end
  end

  describe 'Job.delete' do
    it 'deletes' do
      job = TestJob.perform_later
      expect { TestJob.delete(job) }.to change(Marj::Record, :count).from(1).to(0)
    end
  end

  describe '#discard' do
    it 'discards' do
      job = TestJob.perform_later
      expect { job.discard }.to change(Marj::Record, :count).from(1).to(0)
    end

    it 'invokes callbacks' do
      job = TestJob.perform_later
      callbacks = []
      job.singleton_class.after_discard { callbacks << 'discarded' }
      expect { job.discard }.to change(Marj::Record, :count).from(1).to(0)
    end
  end

  describe '#delete' do
    it 'deletes' do
      job = TestJob.perform_later
      expect { job.delete }.to change(Marj::Record, :count).from(1).to(0)
    end
  end
end
