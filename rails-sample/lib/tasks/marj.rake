namespace :marj do
  desc 'Test Marj'
  task test: :environment do
    loaded = false
    ActiveSupport.on_load(:active_record) { loaded = true }
    raise "ActiveRecord loaded too soon" if loaded

    Marj.count
    raise "ActiveRecord not loaded" unless loaded

    raise "Unexpected job found" unless Marj.count == 0
    TestJob.perform_later('TestJob.runs << 1')
    raise "Job not enqueued" unless Marj.count == 1

    Marj.first.execute
    raise "Job not executed" unless TestJob.runs == [1]
    raise "Job not deleted" unless Marj.count == 0
  end
end
