# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Record Serialization' do
  describe '#arguments' do
    context 'deserialize' do
      subject { MarjRecord.first.arguments }

      before do
        TestJob.perform_later(Time.now, 1, 'foo')
      end

      it 'deserializes the arguments' do
        expect(subject).to be_a(Array)
        expect(subject[0]).to be_a(Time)
        expect(subject[1]).to be_a(Integer)
        expect(subject[2]).to be_a(String)
      end
    end

    context 'serialization' do
      it 'serializes the arguments' do
        TestJob.perform_later
        MarjRecord.first.update!(arguments: [Time.now, 1, 'foo'])
        expect(MarjRecord.first.arguments).to be_a(Array)
        expect(MarjRecord.first.arguments[0]).to be_a(Time)
        expect(MarjRecord.first.arguments[1]).to be_a(Integer)
        expect(MarjRecord.first.arguments[2]).to be_a(String)
      end

      it 'allows already serialized arguments' do
        TestJob.perform_later
        MarjRecord.first.update!(arguments: '[1, "foo"]')
        expect(MarjRecord.first.arguments).to be_a(Array)
        expect(MarjRecord.first.arguments[0]).to be_a(Integer)
        expect(MarjRecord.first.arguments[1]).to be_a(String)
      end

      it 'raises on unexpected arguments' do
        TestJob.perform_later
        expect { MarjRecord.first.update!(arguments: 1) }.to raise_error(StandardError, 'invalid arguments: 1')
      end
    end
  end

  describe '#exception_executions' do
    context 'deserialize' do
      subject { MarjRecord.first.exception_executions }

      before do
        job = TestJob.new
        job.exception_executions = { '[Exception]' => 1 }
        job.enqueue
      end

      it 'deserializes the exception_executions' do
        expect(subject).to eq({ '[Exception]' => 1 })
      end
    end

    context 'serialization' do
      subject { MarjRecord.first.update!(exception_executions: { '[Foo]' => 2 }) }

      before do
        TestJob.perform_later
      end

      it 'deserializes the job_class' do
        subject
        expect(MarjRecord.first.exception_executions).to eq({ '[Foo]' => 2 })
      end
    end
  end

  describe '#job_class' do
    context 'deserialize' do
      subject { MarjRecord.first.job_class }

      before do
        TestJob.perform_later(Time.now, 1, 'foo')
      end

      it 'deserializes the job_class' do
        expect(subject).to eq(TestJob)
      end
    end

    context 'serialization' do
      it 'deserializes the job_class' do
        TestJob.perform_later
        MarjRecord.first.update!(job_class: String)
        expect(MarjRecord.first.job_class).to eq(String)
      end

      it 'raises on unexpected job_class' do
        TestJob.perform_later
        expect { MarjRecord.first.update!(job_class: 1) }.to raise_error(StandardError, 'invalid class: 1')
      end
    end
  end
end
