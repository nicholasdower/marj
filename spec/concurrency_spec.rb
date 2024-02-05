# frozen_string_literal: true

require_relative 'spec_helper'

describe 'Concurrency' do
  before do
    stub_const('MyJob', Class.new(TestJob) do
      around_perform do |job, block|
        raise "Job #{job.job_id} already claimed" if job.queue_name.start_with?('claimed')

        updated = Marj::Record.where(job_id: job.job_id, queue_name: job.queue_name)
                              .update_all(queue_name: "claimed-#{job.queue_name}", scheduled_at: Time.now.utc)
        raise "Failed to claim job #{job.job_id}. #{updated} records updated" unless updated == 1

        begin
          block.call
        rescue StandardError
          Marj::Record.where(job_id: job.job_id, queue_name: "claimed-#{job.queue_name}")
                      .update_all(queue_name: job.queue_name, scheduled_at: job.scheduled_at)
          raise
        end
      end
    end)
  end

  it 'claims before executing' do
    job = MyJob.perform_later('TestJob.runs << Marj::Record.first.queue_name')
    job.perform_now
    expect(TestJob.runs).to eq(['claimed-default'])
  end

  it 'releases after failing' do
    job = MyJob.perform_later('raise "hi"')
    job.perform_now
    expect(Marj::Record.first.queue_name).to eq('default')
  end

  it 'does not break discarded job retention' do
    MyJob.queue_adapter = MarjAdapter.new(discard: proc { _1.enqueue(queue: 'discarded') })
    job = MyJob.perform_later('raise "hi"')
    job.perform_now
    expect { job.perform_now }.to raise_error(StandardError, 'hi')
    expect(Marj::Record.first.queue_name).to eq('discarded')
  end

  it 'releases before discarding' do
    queues = []
    MyJob.after_discard { |_job| queues << Marj::Record.first.queue_name }
    job = MyJob.perform_later('raise "hi"')
    job.perform_now
    expect { job.perform_now }.to raise_error(StandardError, 'hi')
    expect(queues.sole).to eq('default')
  end

  it 'does not break discarding' do
    job = MyJob.perform_later('raise "hi"')
    job.perform_now
    expect(Marj::Record.count).to eq(1)
    expect { job.perform_now }.to raise_error(StandardError, 'hi')
    expect(Marj::Record.count).to eq(0)
  end
end
