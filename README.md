# Marj - Minimal ActiveRecord Jobs

A minimal database-backed ActiveJob queueing backend.

## Quick Links

API docs: https://gemdocs.org/gems/marj/6.0.0.pre/ <br>
RubyGems: https://rubygems.org/gems/marj <br>
Changelog: https://github.com/nicholasdower/marj/releases <br>
Issues: https://github.com/nicholasdower/marj/issues <br>
Development: https://github.com/nicholasdower/marj/blob/master/CONTRIBUTING.md

## Motivation

There are alrady several great database-backed ActiveJob queueing backends:
- [Delayed::Job](https://github.com/collectiveidea/delayed_job)
- [Que](https://github.com/que-rb/que)
- [GoodJob](https://github.com/bensheldon/good_job)
- [Solid Queue](https://github.com/basecamp/solid_queue)

Any of these which support your RDBMS are likely to work well for you.

But you may find each to be more featureful and complex than what you require.

Marj aims to be a minimal alternative.

## Goals

To be the database-backend ActiveJob queueing backend with:
- The simplest setup
- The fewest configuration options
- The fewest features
- The fewest backend-specific APIs
- The fewest lines of code

## Features

Marj supports and has been tested on MySQL, PostgreSQL and SQLite.

It provides the following features:
- Enqueued jobs are written to the database.
- Enqueued jobs can be queried, executed and discarded.
- Executed jobs are re-enqueued or discarded, depending on the result.

## Missing Features

Marj does not provide the following features:
- Automatic job execution - query and execute jobs wherever you like
- Concurrent job execution - use one thread or one thread per queue
- Job timeouts - timeouts are easy to add to your job classes (see below)
- Observability - expose metrics via job callbacks (see below)
- A user interace - See [Mission Control](https://github.com/basecamp/mission_control-jobs)

## API

Marj relies on existing ActiveJob APIs, for example:

```ruby
job.enqueue         # Enqueues a job
job.perform_now     # Performs a job
```

Additionally, it extends the ActiveJob API with two methods required for a
minimal queueing backend implementaion:

```ruby
SomeJob.query(args) # Queries for enqeueued jobs
job.discard         # Discards a job
```

## Setup

### 1. Install

```shell
bundle add activejob activerecord marj
```

### 2. Create the database table

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

```ruby
require 'marj'

Rails.configuration.active_job.queue_adapter = :marj # Globally, with Rails
ActiveJob::Base.queue_adapter = :marj                # Globally, without Rails
SomeJob.queue_adapter = :marj                        # Single job
```

### 4. Optionally, include the Marj module

Without any additional setup, jobs can be queried and discarded via the `Marj`
module:

```ruby
Marj.query(:all)
Marj.discard(job)
```

But it is also convenient to query or discard via job classes:

```ruby
SomeJob.query(:all)
SomeJob.discard(job)
job.discard
```

In order to enable this functionality, you must include the `Marj` module:

```ruby
class SomeJob < ActiveJob::Base
  include Marj

  def perform; end
end
```

## Example Usage

```ruby
# Enqueue a job
job = SomeJob.perform_later('foo')

# Query jobs
SomeJob.query(:all)
SomeJob.query(:due)
SomeJob.query(:due, queue: :foo)
SomeJob.query('8720417d-8fff-4fcf-bc16-22aaef8543d2')

# Execute a job
job.perform_now

# Execute jobs which are due (single query)
SomeJob.query(:due).map(&:perform_now)

# Execute jobs which are due (multiple queries)
loop {
  SomeJob.query(:due, :first)&.tap(&:perform_now) || break
end

# Execute jobs as they become due
loop do
  SomeJob.query(:due).each(&:perform_now) rescue logger.error($!)
ensure
  sleep 5.seconds
end
```

## Testing

By default, jobs enqeued during tests will be written to the database. Enqueued
jobs can be executed via:

```ruby
SomeJob.query(:due).map(&:perform_now)
```

Alternatively, to use ActiveJob's [TestAdapter](https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/TestAdapter.html):
```ruby
ActiveJob::Base.queue_adapter = :test
```

## Extension Examples

Most missing features can easily be added to your application.

### Timeouts

```ruby
class ApplicationJob < ActiveJob::Base
  def self.timeout_after(duration)
    @timeout = duration
  end

  around_perform do |job, block|
    if (timeout = job.class.instance_variable_get(:@timeout))
      ::Timeout.timeout(timeout, StandardError, 'execution expired') do
        block.call
      end
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
      error = backtrace ?
        "#{error.class}: #{error.message}\n#{backtrace}" :
        "#{error.class}: #{error.message}"
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

### Custom DB Setup

It is possible to create a custom record class in order to, for instance,
use a different class or table name, or write jobs to multiple
databases/tables within a single application.

Assuming you have a jobs tabled named `my_jobs`:

```ruby
class MyRecord < Marj::Record
  self.table_name = 'my_jobs'
end

class MyJob < ActiveJob::Base
  self.queue_adapter = MarjAdapter.new('MyRecord')

  include Marj

  def perform; end
end

MyJob.perform_later('oh, hi')
MyJob.query(:due, :first).perform_now
```

## ActiveJob Cheatsheet

For more information on ActiveJob, see:

- https://edgeguides.rubyonrails.org/active_job_basics.html
- https://www.rubydoc.info/gems/activejob
- https://github.com/nicholasdower/marj/blob/master/README.md#activejob-cheatsheet

### Configuring a Queue Adapter

```ruby
# With Rails
Rails.configuration.active_job.queue_adapter = :foo # Instantiates FooAdapter
Rails.configuration.active_job.queue_adapter = FooAdapter.new

# Without Rails
ActiveJob::Base.queue_adapter = :foo               # Instantiates FooAdapter
ActiveJob::Base.queue_adapter = FooAdapter.new     # Uses FooAdapter directly

# Single Job
SomeJob.queue_adapter = :foo                       # Instantiates FooAdapter
SomeJob.queue_adapter = FooAdapter.new             # Uses FooAdapter directly
```

### Configuration

```ruby
config.active_job.default_queue_name
config.active_job.queue_name_prefix
config.active_job.queue_name_delimiter
config.active_job.retry_jitter
SomeJob.queue_name
SomeJob.queue_as
SomeJob.queue_name_prefix
SomeJob.queue_name_delimiter
SomeJob.retry_jitter
```

### Options

```ruby
:wait       # Enqueues the job with the specified delay
:wait_until # Enqueues the job at the time specified
:queue      # Enqueues the job on the specified queue
:priority   # Enqueues the job with the specified priority
```

### Callbacks

```ruby
SomeJob.before_enqueue
SomeJob.after_enqueue
SomeJob.around_enqueue
SomeJob.before_perform
SomeJob.after_perform
SomeJob.around_perform
ActiveJob::Callbacks.singleton_class.set_callback(:execute, :before, &block)
ActiveJob::Callbacks.singleton_class.set_callback(:execute, :after, &block)
ActiveJob::Callbacks.singleton_class.set_callback(:execute, :around, &block)
```

### Handling Exceptions

```ruby
SomeJob.retry_on
SomeJob.discard_on
SomeJob.after_discard
```

### Creating Jobs

```ruby
# Create without enqueueing
job = SomeJob.new
job = SomeJob.new(args)
job = SomeJob.new.deserialize(other_job.serialize)

# Create and enqueue
job = SomeJob.perform_later
job = SomeJob.perform_later(args)

# Create without enqueueing and run (only enqueued on failure if retryable)
SomeJob.perform_now
SomeJob.perform_now(args)
```

### Enqueueing Jobs

Jobs are enqueued via the `ActiveJob::Base#enqueue` method. This method returns
the job on success. If an error is raised during enqueueing, that error will
propagate to the caller, unless the error is an `ActiveJob::EnqueueError`. In
this case, `enqueue` will return `false` and `job.enqueue_error` will be set.

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
SomeJob.set(options).perform_all_later(SomeJob.new, SomeJob.new)
SomeJob.set(options).perform_all_later(SomeJob.new, SomeJob.new, options:)
```

### Executing Jobs

```ruby
# Executed without enqueueing, enqueued on failure if retryable
SomeJob.new(args).perform_now
SomeJob.perform_now(args)
ActiveJob::Base.execute(SomeJob.new(args).serialize)

# Executed after enqueueing
SomeJob.perform_later(args).perform_now
ActiveJob::Base.execute(SomeJob.perform_later(args).serialize)
```
