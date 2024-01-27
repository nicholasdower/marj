# Marj - Minimal ActiveRecord Jobs

A minimal database-backed ActiveJob queueing backend.

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
- An interface is provided to retrieve, execute, discard and re-enqueue jobs.
- An `ActiveRecord` model class is provided to query the database directly.

## Features Not Provided

- Workers
- Timeouts
- Concurrency Controls
- Observability
- A User Interace

## Setup

### 1. Install

```shell
bundle add activejob activerecord marj

# or

gem install activejob activerecord marj
```

### 3. Create the jobs table

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

Rails.configuration.active_job.queue_adapter = :marj # Globally, with Rails
ActiveJob::Base.queue_adapter = :marj                # Globally, without Rails
SomeJob.queue_adapter = :marj                        # Single job
```

## Jobs Interface

`Marj::Jobs` provides a query interface which can be used to retrieve, execute
and discard enqueued jobs. It returns, yields and accepts `ActiveJob` objects
rather than `ActiveRecord` objects. To query the database directly, use
`Marj::Record`.

```ruby
Marj::Jobs.all         # Returns all enqueued jobs.
Marj::Jobs.queue       # Returns jobs in the specified queue(s).
Marj::Jobs.ready       # Returns jobs which are ready to be executed.
Marj::Jobs.first       # Returns the first job(s) by enqueued_at.
Marj::Jobs.last        # Returns the last job(s) by enqueued_at.
Marj::Jobs.count       # Returns the number of enqueued jobs.
Marj::Jobs.where       # Returns jobs matching the specified criteria.
Marj::Jobs.perform_all # Executes all jobs.
Marj::Jobs.discard_all # Discards all jobs.
Marj::Jobs.discard     # Discards the specified job.
```

`all`, `queue`, `ready` and `where` return a `Marj::Relation` which provides
the same query methods as `Marj::Jobs`. This can be used to chain query methods
like:

```ruby
Marj::Jobs.where(job_class: SomeJob).ready.first
```

Note that the `Marj::Jobs` interface can be added to any class or module. For
example, to add the jobs interface to all jobs classes:

```ruby
class ApplicationJob < ActiveJob::Base
  extend Marj::JobsInterface

  def self.all
    Marj::Relation.new(
      self == ApplicationJob ?
        Marj::Record.all : Marj::Record.where(job_class: self)
   )
  end
end

class SomeJob < ApplicationJob; end

ApplicationJob.ready # Returns all jobs which are ready to be executed.
SomeJob.ready        # Returns SomeJobs which are ready to be executed.
```

## Example Usage

```ruby
# Enqueue and manually run a job:
job = SomeJob.perform_later('foo')
job.perform_now

# Retrieve a job
Marj::Jobs.last

# Retrieve and execute a job
Marj::Jobs.ready.first.perform_now

# Run all ready jobs (single DB query)
Marj::Jobs.ready.perform_all

# Run all ready jobs (multiple DB queries)
Marj::Jobs.ready.perform_all(batch_size: 1)

# Run all ready jobs in a specific queue:
Marj::Jobs.queue('foo').ready.perform_all

# Run jobs indefinitely, as they become ready:
loop do
  Marj::Jobs.ready.perform_all rescue logger.error($!)
ensure
  sleep 5.seconds
end
```

## Customization

It is possible to create a custom record class and jobs interface. This enables,
for instance, writing jobs to multiple databases/tables within a single
application.

```
class CreateMyJobs < ActiveRecord::Migration[7.1]
  def self.up
    create_table :my_jobs, id: :string, primary_key: :job_id do |table|
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

    add_index :my_jobs, %i[enqueued_at]
    add_index :my_jobs, %i[scheduled_at]
    add_index :my_jobs, %i[priority scheduled_at enqueued_at]
  end

  def self.down
    drop_table :my_jobs
  end
end

class MyRecord < ActiveRecord::Base
  include Marj::Record::Base
  extend Marj::Record::Base::ClassMethods

  self.table_name = 'my_jobs'
end

CreateMyJobs.migrate(:up)

class ApplicationJob < ActiveJob::Base
  self.queue_adapter = MarjAdapter.new('MyRecord')

  extend Marj::JobsInterface

  def self.all
    Marj::Relation.new(
      self == ApplicationJob ?
        MyRecord.all : MyRecord.where(job_class: self)
    )
  end
end

class MyJob < ApplicationJob
  def perform(msg)
    puts msg
  end
end

MyJob.perform_later('oh, hi')
MyJob.ready.first.perform_now
```

## Testing

By default, jobs enqeued during tests will be written to the database. Enqueued
jobs can be executed via:

```ruby
Marj::Jobs.ready.perform_all
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

- `config.active_job.default_queue_name`
- `config.active_job.queue_name_prefix`
- `config.active_job.queue_name_delimiter`
- `config.active_job.retry_jitter`
- `SomeJob.queue_name`
- `SomeJob.queue_as`
- `SomeJob.queue_name_prefix`
- `SomeJob.queue_name_delimiter`
- `SomeJob.retry_jitter`

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
