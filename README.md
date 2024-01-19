# Marj

An ActiveJob queuing backend which uses ActiveRecord. 

API docs: https://www.rubydoc.info/github/nicholasdower/marj <br>
RubyGems: https://rubygems.org/gems/marj <br>
Changelog: https://github.com/nicholasdower/marj/releases <br>
Issues: https://github.com/nicholasdower/marj/issues

For more information on ActiveJob, see:

- https://edgeguides.rubyonrails.org/active_job_basics.html
- https://www.rubydoc.info/gems/activejob

## Basic Setup

Add the following to your Gemfile:

```ruby
gem 'marj', '~> 1.0'
```

Apply a database migration:

```ruby
class CreateJobs < ActiveRecord::Migration[7.1]
  def self.up
    create_table :jobs, id: :string, primary_key: :job_id do |table|
      table.string   :job_class, null: false
      table.string   :queue_name
      table.integer  :priority
      table.text     :arguments,            null: false
      table.integer  :executions,           null: false
      table.text     :exception_executions, null: false
      table.string   :locale
      table.string   :timezone
      table.datetime :enqueued_at, null: false
      table.datetime :scheduled_at
    end
  end

  def self.down
    drop_table :jobs
  end
end
```

If using Rails, configure the queue adapter via `Rails::Application`:

```ruby
class MyApplication < Rails::Application
  require 'marj'
  config.active_job.queue_adapter = :marj
end
```

If not using Rails, configure the queue adapter via `ActiveJob::Base`:

```ruby
ActiveJob::Base.queue_adapter = :marj
```

Alternatively, configure for a single job:

```ruby
SomeJob.queue_adapter = :marj
```

## ActiveJob Cheatsheet

### Configuring a Queue Adapter

```ruby
# With Rails
class MyApplication < Rails::Application
  config.active_job.queue_adapter = :foo           # Instantiates FooAdapter
  config.active_job.queue_adapter = FooAdapter.new # Uses FooAdapter directly
end

# Without Rails
ActiveJob::Base.queue_adapter = :foo           # Instantiates FooAdapter
ActiveJob::Base.queue_adapter = FooAdapter.new # Uses FooAdapter directly
```

### Creating Jobs

```ruby
job = SampleJob.new                 # Created without args, not enqueued
job = SampleJob.new(args)           # Created with args, not enqueued

job = SampleJob.perform_later       # Enqueued without args
job = SampleJob.perform_later(args) # Enqueued with args

SampleJob.perform_now               # Created without args, not enqueued unless retried
SampleJob.perform_now(args)         # Created with args, ot enqueued unless retried
```

### Enqueueing Jobs

```ruby
SampleJob.new(args).enqueue                    # Enqueued without options
SampleJob.new(args).enqueue(options)           # Enqueued with options

SampleJob.perform_later(args)                  # Enqueued without options
SampleJob.options(options).perform_later(args) # Enqueued with options

SampleJob.perform_now(args)                    # Enqueued on failure if retries configured

ActiveJob.perform_all_later(                   # All enqueued without options
  SampleJob.new, SampleJob.new
)
ActiveJob.perform_all_later(                   # All enqueued with options
  SampleJob.new, SampleJob.new, options:
)

SampleJob                                      # All enqueued without options
  .set(options)
  .perform_all_later(
    SampleJob.new, SampleJob.new
  )
SampleJob                                      # All enqueued with options
  .set(options)
  .perform_all_later(
    SampleJob.new, SampleJob.new, options:
  )
```

### Executing Jobs

```ruby
# Executed without enqueueing, enqueued on failure if retries configured
SampleJob.new(args).perform_now
SampleJob.perform_now(args)
ActiveJob::Base.exeucute(SampleJob.new(args).serialize)

# Executed after enqueueing
SampleJob.perform_later(args).perform_now
ActiveJob::Base.exeucute(SampleJob.perform_later(args).serialize)
```
