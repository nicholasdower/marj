# frozen_string_literal: true

require_relative '../../spec_helper'

describe 'Marj Execution' do
  describe '#exeucte' do
    it 'executes the job' do
      TestJob.perform_later('TestJob.runs << 1')
      expect(TestJob.runs).to eq([])
      Marj.last.execute
      expect(TestJob.runs).to eq([1])
    end

    it 'returns the result' do
      TestJob.perform_later('1')
      expect(Marj.last.execute).to eq([1])
    end

    it 'deletes the job on success' do
      TestJob.perform_later('TestJob.runs << 1')
      expect(Marj.count).to eq(1)
      Marj.last.execute
      expect(Marj.count).to eq(0)
    end

    it 're-enqueues the job on failure' do
      TestJob.perform_later('raise "hi"')
      expect(Marj.last.executions).to eq(0)
      Marj.last.execute
      expect(Marj.last.executions).to eq(1)
    end

    it 'returns the error on failure' do
      TestJob.perform_later('raise "hi"')
      result = Marj.last.execute
      expect(result).to be_a(StandardError)
      expect(result.message).to eq('hi')
    end

    it 'deletes the job on discard' do
      TestJob.perform_later('raise "hi"')
      expect(Marj.count).to eq(1)
      Marj.last.execute
      expect(Marj.count).to eq(1)
      Marj.last.execute rescue nil
      expect(Marj.count).to eq(0)
    end

    it 'raises on discard' do
      TestJob.perform_later('raise "hi"')
      Marj.last.execute
      expect { Marj.last.execute }.to raise_error(StandardError, 'hi')
    end
  end
end
