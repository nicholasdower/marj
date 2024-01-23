# frozen_string_literal: true

require_relative '../../spec_helper'

describe Marj do
  describe '#register_callbacks' do
    context 'when callbacks already registered' do
      it 'raises' do
        job = TestJob.perform_later
        expect { Marj.send(:register_callbacks, job, Marj.first) }.to raise_error(RuntimeError, /already registered/)
      end
    end
  end
end
