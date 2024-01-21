# Marj

Marj is a Minimal ActiveRecord-based Jobs library.

API docs: https://www.rubydoc.info/github/nicholasdower/marj <br>
RubyGems: https://rubygems.org/gems/marj <br>
Changelog: https://github.com/nicholasdower/marj/releases <br>
Issues: https://github.com/nicholasdower/marj/issues

For more information on ActiveJob, see:

- https://edgeguides.rubyonrails.org/active_job_basics.html
- https://www.rubydoc.info/gems/activejob

## Setup

### 1. Install

Add the following to your Gemfile:

```ruby
gem 'marj', '~> 1.0'
```

### 2. Create the jobs table

Apply a database migration:

```ruby
class CreateJobs < ActiveRecord::Migration[7.1]
  def self.up
    create_table :jobs, id: :string, primary_key: :job_id do |table|
      table.string   :job_class,            null: false
      table.text     :arguments,            null: false
      table.string   :queue_name,           null: false
      table.integer  :priority
      table.integer  :executions,           null: false
      table.text     :exception_executions, null: false
      table.datetime :enqueued_at,          null: false
      table.datetime :scheduled_at
      table.string   :locale,               null: false
      table.string   :timezone,             null: false
    end

    add_index :jobs, %i[enqueued_at]
    add_index :jobs, %i[scheduled_at]
    add_index :jobs, %i[priority scheduled_at enqueued_at]
  end

  def self.down
    drop_table :jobs
  end
end
```

### 3. Configure the queue adapter

If using Rails, configure the queue adapter via `Rails::Application`:

```ruby
require 'marj'

# Configure via Rails::Application:
class MyApplication < Rails::Application
  config.active_job.queue_adapter = :marj
end

# Or for specific jobs:
class SomeJob < ActiveJob::Base
  self.queue_adapter = :marj
end
```

If not using Rails:

```ruby
require 'marj'
require 'marj_record' # Loads ActiveRecord

# Configure via ActiveJob::Base:
ActiveJob::Base.queue_adapter = :marj

# Or for specific jobs:
class SomeJob < ActiveJob::Base
  self.queue_adapter = :marj
end
```

## Example Usage

```ruby
# Enqueue and manually run a job:
job = SampleJob.perform_later('foo')
job.perform_now

# Enqueue, retrieve and manually run a job:
SampleJob.perform_later('foo')
Marj.first.execute

# Run all available jobs:
Marj.work_off

# Run jobs as they become available:
loop do
  Marj.work_off
  sleep 5.seconds
end
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
ActiveJob::Base.queue_adapter = :foo               # Instantiates FooAdapter
ActiveJob::Base.queue_adapter = FooAdapter.new     # Uses FooAdapter directly
```

### Options

- `:wait` - Enqueues the job with the specified delay
- `:wait_until` - Enqueues the job at the time specified
- `:queue` - Enqueues the job on the specified queue
- `:priority` - Enqueues the job with the specified priority

### Callbacks

- `before_enqueue`
- `after_enqueue`
- `around_enqueue`
- `before_perform`
- `after_perform`
- `around_perform`

## Handling Exceptions

- `retry_on`
- `discard_on`
- `after_discard`

## Configuration

- `config.active_job.retry_jitter`
- `config.active_job.default_queue_name`
- `config.active_job.queue_name_prefix`
- `config.active_job.queue_name_delimiter`
- `retry_jitter`
- `queue_name`
- `queue_as`

### Creating Jobs

```ruby
# Create without enqueueing
job = SampleJob.new
job = SampleJob.new(args)
                                                   
# Create and enqueue
job = SampleJob.perform_later
job = SampleJob.perform_later(args)
                                                   
# Create and run (enqueued on failure)
SampleJob.perform_now
SampleJob.perform_now(args)
```                                                
                                                   
### Enqueueing Jobs                                
                                                   
```ruby                                            
SampleJob.new(args).enqueue
SampleJob.new(args).enqueue(options)
                                                   
SampleJob.perform_later(args)
SampleJob.set(options).perform_later(args)
                                                   
# Enqueued on failure
SampleJob.perform_now(args)
                                                   
# Enqueue multiple
ActiveJob.perform_all_later(SampleJob.new, SampleJob.new)                                                  
ActiveJob.perform_all_later(SampleJob.new, SampleJob.new, options:)                                                  
                                                   
# Enqueue multiple
SampleJob.set(options).perform_all_later(SampleJob.new, SampleJob.new)                                                
SampleJob.set(options).perform_all_later(SampleJob.new, SampleJob.new, options:)
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
