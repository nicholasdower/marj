# frozen_string_literal: true

require_relative '../spec_helper'

describe Marj do
  describe '#register_callbacks' do
    context 'when callbacks already registered' do
      it 'raises' do
        job = TestJob.perform_later
        expect { Marj.send(:register_callbacks, job, Marj.first) }.to raise_error(RuntimeError, /already registered/)
      end

      it 'does not register re-register callbacks' do
        job = TestJob.perform_later

        expect(job.singleton_class).not_to receive(:after_perform)
        expect(job.singleton_class).not_to receive(:after_discard)
        Marj.send(:register_callbacks, job, Marj.first) rescue nil
      end
    end
  end
end
