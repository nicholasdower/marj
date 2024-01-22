# Contributing

## Setup

Install Ruby 3.3.0.

## Development

```shell
make console  # Start an interactive console
make rspec    # Run tests
make coverage # Generate test coverage report
make doc      # Generate documentation
make rubocop  # Run RuboCop
```

## Logs

To set the log level:

```shell
LEVEL=0 make rspec
LEVEL=0 make console
```

## MySQL

To use MySQL rather than SQLite, [install Docker](https://docs.docker.com/get-docker), then:

```shell
make rspec-mysql
make console-mysql
make mysql-client
```

## PostgreSQL

To use PostgreSQL rather than SQLite, [install Docker](https://docs.docker.com/get-docker), then:

```shell
make rspec-postgres
make console-postgres
make postgres-client
```
