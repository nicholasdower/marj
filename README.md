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
require 'marj/record' # Loads ActiveRecord

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
job = SomeJob.perform_later('foo')
job.perform_now

# Enqueue, retrieve and manually run a job:
SomeJob.perform_later('foo')
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

# Single Job
SomeJob.queue_adapter = :foo                       # Instantiates FooAdapter
SomeJob.queue_adapter = FooAdapter.new             # Uses FooAdapter directly
```

### Configuration

- `config.active_job.default_queue_name`
- `config.active_job.queue_name_prefix`
- `config.active_job.queue_name_delimiter`
- `config.active_job.retry_jitter`
- `SomeJob.queue_name_prefix`
- `SomeJob.queue_name_delimiter`
- `SomeJob.retry_jitter`
- `SomeJob.queue_name`
- `SomeJob.queue_as`

### Options

- `:wait` - Enqueues the job with the specified delay
- `:wait_until` - Enqueues the job at the time specified
- `:queue` - Enqueues the job on the specified queue
- `:priority` - Enqueues the job with the specified priority

### Callbacks

- `SomeJob.before_enqueue`
- `SomeJob.after_enqueue`
- `SomeJob.around_enqueue`
- `SomeJob.before_perform`
- `SomeJob.after_perform`
- `SomeJob.around_perform`
- `ActiveJob::Callbacks.singleton_class.set_callback(:execute, :before, &block)`
- `ActiveJob::Callbacks.singleton_class.set_callback(:execute, :after, &block)`
- `ActiveJob::Callbacks.singleton_class.set_callback(:execute, :around, &block)`

### Handling Exceptions

- `SomeJob.retry_on`
- `SomeJob.discard_on`
- `SomeJob.after_discard`

### Creating Jobs

```ruby
# Create without enqueueing
job = SomeJob.new
job = SomeJob.new(args)

# Create and enqueue
job = SomeJob.perform_later
job = SomeJob.perform_later(args)

# Create and run (enqueued on failure)
SomeJob.perform_now
SomeJob.perform_now(args)
```

### Enqueueing Jobs

```ruby
SomeJob.new(args).enqueue
SomeJob.new(args).enqueue(options)

SomeJob.perform_later(args)
SomeJob.set(options).perform_later(args)

# Enqueued on failure
SomeJob.perform_now(args)

# Enqueue multiple
ActiveJob.perform_all_later(SomeJob.new, SomeJob.new)
ActiveJob.perform_all_later(SomeJob.new, SomeJob.new, options:)

# Enqueue multiple
SomeJob.set(options).perform_all_later(SomeJob.new, SomeJob.new)
SomeJob.set(options).perform_all_later(SomeJob.new, SomeJob.new, options:)
```

### Executing Jobs

```ruby
# Executed without enqueueing, enqueued on failure if retries configured
SomeJob.new(args).perform_now
SomeJob.perform_now(args)
ActiveJob::Base.exeucute(SomeJob.new(args).serialize)

# Executed after enqueueing
SomeJob.perform_later(args).perform_now
ActiveJob::Base.exeucute(SomeJob.perform_later(args).serialize)
```
