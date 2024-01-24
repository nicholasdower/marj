# frozen_string_literal: true

require_relative '../spec_helper'

describe Marj do
  describe '#register_callbacks' do
    context 'when callbacks already registered' do
      it 'updates the record reference' do
        job = TestJob.perform_later
        old_record = job.singleton_class.instance_variable_get(:@__marj)
        new_record = Marj.first
        Marj.send(:register_callbacks, job, new_record)
        expect(job.singleton_class.instance_variable_get(:@__marj)).not_to equal(old_record)
        expect(job.singleton_class.instance_variable_get(:@__marj)).to equal(new_record)
      end

      it 'does not register re-register callbacks' do
        job = TestJob.perform_later

        expect(job.singleton_class).not_to receive(:after_perform)
        expect(job.singleton_class).not_to receive(:after_discard)
        Marj.send(:register_callbacks, job, Marj.first)
      end
    end
  end
end
