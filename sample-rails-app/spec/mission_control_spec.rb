# frozen_string_literal: true

require_relative '../config/environment'

describe ActiveJob do
  before { Marj::Record.delete_all }

  after { TestJob.runs.clear }

  before(:all) do
    server = MissionControl::Jobs::Server.from_global_id('railssample:marj')
    MissionControl::Jobs::Current.server = server
  end

  describe '#jobs' do
    let(:jobs) do
      [
        TestJob.perform_later,
        TestJob.perform_later
      ]
    end

    before { jobs }

    it 'returns job proxies' do
      expect(ActiveJob.jobs.first).to be_a(ActiveJob::JobProxy)
    end

    it 'returns the expected jobs' do
      expect(ActiveJob.jobs.map(&:job_id)).to contain_exactly(*jobs.map(&:job_id))
    end
  end

  describe '#count' do
    before do
      TestJob.perform_later
      TestJob.perform_later
    end

    it 'counts' do
      expect(ActiveJob.jobs.count).to eq(2)
    end
  end

  describe '#find_by_id' do
    let(:job) { TestJob.perform_later }
    let(:other_job) { TestJob.perform_later }

    it 'returns the job' do
      job
      other_job
      expect(ActiveJob.jobs.find_by_id(job.job_id).job_id).to eq(job.job_id)
    end
  end

  describe '#queues' do
    before do
      TestJob.set(queue: 'foo').perform_later
      TestJob.set(queue: 'foo').perform_later
      TestJob.set(queue: 'bar').perform_later
      TestJob.set(queue: 'bar').perform_later
      TestJob.set(queue: 'bar').perform_later
    end

    it 'returns the expected queues' do
      expect(ActiveJob.queues.map(&:name)).to contain_exactly('bar', 'foo')
    end

    it 'returns the expected queue status' do
      expect(ActiveJob.queues.map(&:active?)).to contain_exactly(true, true)
    end

    it 'returns the expected queue sizes' do
      expect(ActiveJob.queues.sort_by(&:name).map(&:size)).to eq([3, 2])
    end
  end

  describe '#limit' do
    let(:job1) { TestJob.perform_later }
    let(:job2) { TestJob.perform_later }
    let(:job3) { TestJob.perform_later }

    before do
      job1
      job2
      job3
    end

    it 'limits the results to 1' do
      expect(ActiveJob.jobs.limit(1).size).to eq(1)
      expect([job1.job_id, job2.job_id, job3.job_id]).to include(*ActiveJob.jobs.limit(1).map(&:job_id).sole)
    end

    it 'limits the results to 2' do
      expect(ActiveJob.jobs.limit(2).size).to eq(2)
      expect([job1.job_id, job2.job_id, job3.job_id]).to include(*ActiveJob.jobs.limit(2).map(&:job_id))
    end
  end

  describe '#offset' do
    let(:job1) { TestJob.perform_later }
    let(:job2) { TestJob.perform_later }
    let(:job3) { TestJob.perform_later }

    before do
      job1
      job2
      job3
    end

    it 'offsets results' do
      first_jobs = ActiveJob.jobs.offset(0).limit(1)
      expect(first_jobs.size).to eq(1)
      second_jobs = ActiveJob.jobs.offset(1).limit(1)
      expect(second_jobs.size).to eq(1)
      expect(first_jobs.sole.job_id).not_to eq(second_jobs.sole.job_id)
    end

    it 'limits the results to 2' do
      expect(ActiveJob.jobs.limit(2).size).to eq(2)
      expect([job1.job_id, job2.job_id, job3.job_id]).to include(*ActiveJob.jobs.limit(2).map(&:job_id))
    end
  end

  describe '#discard' do
    subject { ActiveJob.jobs.discard_job(job_proxy) }

    let(:job) { TestJob.perform_later }
    let(:other_job) { TestJob.perform_later }
    let(:job_proxy) { ActiveJob.jobs.find_by_id(job.job_id) }

    before do
      job
      other_job
    end

    it 'discard the job' do
      expect { subject }.to change { Marj::Record.exists?(job.job_id) }.from(true).to(false)
    end
  end

  describe '#discard_all' do
    subject { ActiveJob.jobs.discard_all }

    before do
      TestJob.set(queue: 'foo').perform_later
      TestJob.set(queue: 'foo').perform_later
      TestJob.set(queue: 'bar').perform_later
    end

    it 'discards all jobs' do
      expect { subject }.to change(Marj::Record, :count).from(3).to(0)
    end

    context 'when query limited' do
      subject { ActiveJob.jobs.where(queue_name: 'foo').discard_all }

      it 'discards the queried jobs' do
        expect { subject }.to change { Marj::Record.where(queue_name: 'foo').count }.from(2).to(0)
        expect(Marj::Record.where(queue_name: 'bar').count).to eq(1)
      end
    end
  end

  context 'status' do
    before do
      TestJob.set(queue: 'scheduled', wait: 5.minutes).perform_later
      TestJob.set(queue: 'scheduled', wait: 5.minutes).perform_later
      TestJob.set(queue: 'pending').perform_later
      failed = TestJob.set(queue: 'failed').perform_later('raise "hi"')
      failed.perform_now
    end

    describe '#with_status(:scheduled)' do
      it 'returns scheduled jobs' do
        queues = ActiveJob.jobs.with_status(:scheduled).map(&:queue_name)
        expect(queues).to contain_exactly('scheduled', 'scheduled', 'failed')
      end
    end

    describe '#scheduled' do
      it 'returns scheduled jobs' do
        queues = ActiveJob.jobs.scheduled.map(&:queue_name)
        expect(queues).to contain_exactly('scheduled', 'scheduled', 'failed')
      end
    end

    describe '#with_status(:pending)' do
      it 'returns pending jobs' do
        queues = ActiveJob.jobs.with_status(:pending).map(&:queue_name)
        expect(queues).to contain_exactly('scheduled', 'scheduled', 'pending', 'failed')
      end
    end

    describe '#pending' do
      it 'returns pending jobs' do
        queues = ActiveJob.jobs.pending.map(&:queue_name)
        expect(queues).to contain_exactly('scheduled', 'scheduled', 'pending', 'failed')
      end
    end

    describe '#with_status(:failed)' do
      it 'returns failed jobs' do
        expect(ActiveJob.jobs.with_status(:failed).map(&:queue_name)).to contain_exactly('failed')
      end
    end

    describe '#failed' do
      it 'returns failed jobs' do
        expect(ActiveJob.jobs.failed.map(&:queue_name)).to contain_exactly('failed')
      end
    end
  end

  describe '#where' do
    let(:test_job) { TestJob.perform_later }
    let(:other_job) { OtherJob.perform_later }

    before do
      test_job
      other_job
    end

    it 'filters by job_class_name' do
      expect(ActiveJob.jobs.where(job_class_name: TestJob).map(&:job_id)).to contain_exactly(test_job.job_id)
    end
  end

  describe '#retry_all' do
    before do
      TestJob.set(queue: 'not_run').perform_later('TestJob.runs << 0')
      job = TestJob.set(queue: 'failed').perform_later('executions == 1 ? raise("hi") : TestJob.runs << 1')
      job.perform_now
      job = TestJob.set(queue: 'failed').perform_later('executions == 1 ? raise("hi") : TestJob.runs << 2')
      job.perform_now
    end

    it 'retries all failed jobs' do
      expect(ActiveJob.jobs.failed.count).to eq(2)
      expect(TestJob.runs).to be_empty
      ActiveJob.jobs.failed.retry_all
      expect(TestJob.runs).to contain_exactly(1, 2)
      expect(Marj::Record.where(queue_name: 'foo').count).to eq(0)
      expect(Marj::Record.where(queue_name: 'not_run').count).to eq(1)
    end
  end

  describe '#retry_job' do
    subject { ActiveJob.jobs.failed.retry_job(job_proxy) }

    let(:job) { TestJob.perform_later('TestJob.runs << 1; raise "hi"') }
    let(:job_proxy) { ActiveJob.jobs.find_by_id(job.job_id) }

    before { job.perform_now }

    it 'retries the job' do
      expect { subject rescue nil }.to change(TestJob, :runs).from([1]).to([1, 1])
    end

    it 'raises' do
      expect { subject }.to raise_error(StandardError, 'hi')
    end
  end
end
