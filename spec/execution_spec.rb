# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Execution' do
  describe '#perform_now' do
    it 'executes the job' do
      TestJob.perform_later('TestJob.runs << 1')
      expect(TestJob.runs).to eq([])
      Marj.query(:all).first.perform_now
      expect(TestJob.runs).to eq([1])
    end

    it 'returns the result' do
      TestJob.perform_later('1')
      expect(Marj.query(:all).first.perform_now).to eq([1])
    end

    it 'deletes the job on success' do
      TestJob.perform_later('TestJob.runs << 1')
      expect(Marj::Record.count).to eq(1)
      Marj.query(:all).first.perform_now
      expect(Marj::Record.count).to eq(0)
    end

    it 'updates the record on success' do
      TestJob.perform_later('TestJob.runs << 1')
      record = Marj::Record.last
      expect { record.to_job.perform_now }.to change { record.destroyed? }.from(false).to(true)
    end

    it 're-enqueues the job on failure' do
      TestJob.perform_later('raise "hi"')
      expect(Marj.query(:all).first.executions).to eq(0)
      Marj.query(:all).first.perform_now
      expect(Marj.query(:all).first.executions).to eq(1)
    end

    it 'returns the error on failure' do
      TestJob.perform_later('raise "hi"')
      result = Marj.query(:all).first.perform_now
      expect(result).to be_a(StandardError)
      expect(result.message).to eq('hi')
    end

    it 'updates the record on failure' do
      TestJob.perform_later('raise "hi"')
      record = Marj::Record.last
      expect { record.to_job.perform_now }.to change { record.executions }.from(0).to(1)
    end

    it 'deletes the job on discard' do
      TestJob.perform_later('raise "hi"')
      expect(Marj::Record.count).to eq(1)
      Marj.query(:all).first.perform_now
      expect(Marj::Record.count).to eq(1)
      Marj.query(:all).first.perform_now rescue nil
      expect(Marj::Record.count).to eq(0)
    end

    it 'updates the record on discard' do
      TestJob.perform_later('raise "hi"')
      record = Marj::Record.last
      job = record.to_job
      job.perform_now
      expect { job.perform_now rescue nil }.to change { record.destroyed? }.from(false).to(true)
    end

    it 'raises on discard' do
      TestJob.perform_later('raise "hi"')
      Marj.query(:all).first.perform_now
      expect { Marj.query(:all).first.perform_now }.to raise_error(StandardError, 'hi')
    end
  end
end
