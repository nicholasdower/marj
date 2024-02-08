# Contributing

## Setup

Install Ruby 3.3.0.

## Commands

```shell
make console     # Start an interactive console
make unit        # Run unit tests
make integration # Run integration tests
make coverage    # Generate test coverage report
make docs        # Generate documentation
make rubocop     # Run RuboCop
make precommit   # Run tests (on all databases), lint, and coverage and generate docs
```

## Console

```ruby
> job = TestJob.perform_later('puts "hi")
> job = TestJob.query(:first)
> job.perform_now
```

## Logs

To set the log level:

```shell
LEVEL=0 make unit
LEVEL=0 make console
```

Or from the console:

```ruby
level 0
```

## MySQL

To use MySQL rather than SQLite, [install Docker](https://docs.docker.com/get-docker), then:

```shell
make unit-mysql
make console-mysql
make mysql-client
```

## PostgreSQL

To use PostgreSQL rather than SQLite, [install Docker](https://docs.docker.com/get-docker), then:

```shell
make unit-postgres
make console-postgres
make postgres-client
```
