# frozen_string_literal: true

require_relative '../../spec_helper'

describe Marj::Record do
  describe 'implicit_order_column' do
    before do
      TestJob.perform_later.tap { Marj::Record.where(job_id: _1.job_id).update(job_id: '2') }
      Timecop.travel(1.minute)
      TestJob.perform_later.tap { Marj::Record.where(job_id: _1.job_id).update(job_id: '1') }
    end

    it 'causes jobs to be ordered by enqueued_at' do
      expect(Marj::Record.first).to have_attributes(job_id: '2')
    end
  end

  describe '.ready' do
    it 'returns jobs where scheduled_at is null' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      expect(Marj::Record.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'returns jobs where scheduled_at is in the past' do
      TestJob.set(queue: '1', wait: 1.minutes).perform_later
      Timecop.travel(2.minutes)
      expect(Marj::Record.ready.map(&:queue_name)).to eq(['1'])
    end

    it 'does not return jobs where scheduled_at is in the future' do
      TestJob.set(queue: '1', wait: 2.minutes).perform_later
      Timecop.travel(1.minute)
      expect(Marj::Record.ready.map(&:queue_name)).to be_empty
    end

    it 'returns jobs with a priority before jobs without a priority' do
      TestJob.set(queue: '1', wait: 2.minute, priority: 1).perform_later
      TestJob.set(queue: '2', wait: 1.minute, priority: nil).perform_later
      Timecop.travel(3.minutes)
      expect(Marj::Record.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a scheduled_at before jobs without a scheduled_at' do
      TestJob.set(queue: '1', wait: 1.minute).perform_later
      TestJob.set(queue: '2').perform_later
      Timecop.travel(2.minutes)
      expect(Marj::Record.ready.map(&:queue_name)).to eq(%w[1 2])
    end

    it 'returns jobs with a sooner enqueued_at before jobs with a later enqueued_at' do
      TestJob.set(queue: '1').perform_later
      Timecop.travel(1.minute)
      TestJob.set(queue: '2').perform_later
      Timecop.travel(1.minute)
      expect(Marj::Record.ready.map(&:queue_name)).to eq(%w[1 2])
    end
  end

  describe '#arguments' do
    context 'deserialize' do
      subject { Marj::Record.first.arguments }

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
        Marj::Record.first.update!(arguments: [Time.now, 1, 'foo'])
        expect(Marj::Record.first.arguments).to be_a(Array)
        expect(Marj::Record.first.arguments[0]).to be_a(Time)
        expect(Marj::Record.first.arguments[1]).to be_a(Integer)
        expect(Marj::Record.first.arguments[2]).to be_a(String)
      end

      it 'allows already serialized arguments' do
        TestJob.perform_later
        Marj::Record.first.update!(arguments: '[1, "foo"]')
        expect(Marj::Record.first.arguments).to be_a(Array)
        expect(Marj::Record.first.arguments[0]).to be_a(Integer)
        expect(Marj::Record.first.arguments[1]).to be_a(String)
      end

      it 'raises on unexpected arguments' do
        TestJob.perform_later
        expect { Marj::Record.first.update!(arguments: 1) }.to raise_error(StandardError, 'invalid arguments: 1')
      end
    end
  end

  describe '#exception_executions' do
    context 'deserialize' do
      subject { Marj::Record.first.exception_executions }

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
      subject { Marj::Record.first.update!(exception_executions: { '[Foo]' => 2 }) }

      before do
        TestJob.perform_later
      end

      it 'deserializes the job_class' do
        subject
        expect(Marj::Record.first.exception_executions).to eq({ '[Foo]' => 2 })
      end
    end
  end

  describe '#job_class' do
    context 'deserialize' do
      subject { Marj::Record.first.job_class }

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
        Marj::Record.first.update!(job_class: String)
        expect(Marj::Record.first.job_class).to eq(String)
      end

      it 'raises on unexpected job_class' do
        TestJob.perform_later
        expect { Marj::Record.first.update!(job_class: 1) }.to raise_error(StandardError, 'invalid class: 1')
      end
    end
  end
end
