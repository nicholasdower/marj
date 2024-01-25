# Marj - Minimal ActiveRecord Jobs

The simplest database-backed ActiveJob queueing backend.

## Quick Links

API docs: https://www.rubydoc.info/github/nicholasdower/marj <br>
RubyGems: https://rubygems.org/gems/marj <br>
Changelog: https://github.com/nicholasdower/marj/releases <br>
Issues: https://github.com/nicholasdower/marj/issues <br>
Development: https://github.com/nicholasdower/marj/blob/master/CONTRIBUTING.md

## Features

- Enqueued jobs are written to the database.
- Successfully executed jobs are deleted from the database.
- Failed jobs which should be retried are updated in the database.
- Failed jobs which should not be retried are deleted from the database.

## Features Not Provided

- Workers
- Timeouts
- Concurrency Controls
- Observability
- A User Interace
- Anything else you might dream up.

## Interface

- `Marj` - An ActiveRecord model class
- `Marj.ready` - Used to retrieve jobs ready to be executed
- `Marj#execute` - Used to execute jobs retrieved from the database
- `MarjConfig.table_name=` - Used to override the default table name

## Setup

### 1. Install

```shell
bundle add marj

# or

gem install marj
```

### 2. Configure

By default, the database table is named "jobs". To use a different table name:

```ruby
require 'marj'

MarjConfig.table_name = 'some_name'
```

### 3. Create the database table

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

### 4. Configure the queue adapter

```ruby
require 'marj'

# With rails:
class MyApplication < Rails::Application
  config.active_job.queue_adapter = :marj
end

# Without Rails:
ActiveJob::Base.queue_adapter = :marj

# Or for specific jobs (with or without Rails):
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

# Run all ready jobs:
Marj.ready.each(&:execute)

# Run all ready jobs, querying each time:
loop { Marj.ready.first&.tap(&:execute) || break }

# Run all ready jobs in a specific queue:
loop { Marj.where(queue_name: 'foo').ready.first&.tap(&:execute) || break }

# Run jobs as they become ready:
loop do
  loop { Marj.ready.first&.tap(&:execute) || break }
rescue Exception => e
  logger.error(e)
ensure
  sleep 5.seconds
end
```

## Testing

By default, jobs enqeued during tests will be written to the database. Enqueued jobs can be executed via:

```ruby
Marj.ready.each(&:execute)
```

Alternatively, to use [ActiveJob::QueueAdapters::TestAdapter](https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/TestAdapter.html):
```ruby
ActiveJob::Base.queue_adapter = :test
```

## Extension Examples

### Timeouts

```ruby
class ApplicationJob < ActiveJob::Base
  def self.timeout_after(duration)
    @timeout = duration
  end

  around_perform do |job, block|
    if (timeout = job.class.instance_variable_get(:@timeout))
      ::Timeout.timeout(timeout, StandardError, 'execution expired') { block.call }
    else
      block.call
    end
  end
end
```

### Last Error

```ruby
class AddLastErrorToJobs < ActiveRecord::Migration[7.1]
  def self.up
    add_column :jobs, :last_error, :text
  end

  def self.down
    remove_column :jobs, :last_error
  end
end

class ApplicationJob < ActiveJob::Base
  attr_reader :last_error

  def last_error=(error)
    if error.is_a?(Exception)
      backtrace = error.backtrace&.map { |line| "\t#{line}" }&.join("\n")
      error = backtrace ? "#{error.class}: #{error.message}\n#{backtrace}" : "#{error.class}: #{error.message}"
    end

    @last_error = error&.truncate(10_000, omission: '… (truncated)')
  end

  def set(options = {})
    super.tap { self.last_error = options[:error] if options[:error] }
  end

  def serialize
    super.merge('last_error' => @last_error)
  end

  def deserialize(job_data)
    super.tap { self.last_error = job_data['last_error'] }
  end
end
```

## ActiveJob Cheatsheet

For more information on ActiveJob, see:

- https://edgeguides.rubyonrails.org/active_job_basics.html
- https://www.rubydoc.info/gems/activejob
- https://github.com/nicholasdower/marj/blob/master/README.md#activejob-cheatsheet

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

Jobs are enqueued via the `ActiveJob::Base#enqueue` method. This method returns the job on
success. If an error is raised during enqueueing, that error will propagate to the caller,
unless the error is an `ActiveJob::EnqueueError`. In this case, `enqueue` will return `false`
and `job.enqueue_error` will be set.

```ruby
SomeJob.new(args).enqueue
SomeJob.new(args).enqueue(options)

# Via perform_later
SomeJob.perform_later(SomeJob.new(args))
SomeJob.perform_later(args)
SomeJob.set(options).perform_later(args)

# After a failure during execution
SomeJob.perform_now(args)
ActiveJob::Base.execute(SomeJob.new(args).serialize)

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
ActiveJob::Base.execute(SomeJob.new(args).serialize)

# Executed after enqueueing
SomeJob.perform_later(args).perform_now
ActiveJob::Base.execute(SomeJob.perform_later(args).serialize)
```
