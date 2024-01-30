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
  end
end
