# Contributing

## Setup

Install Ruby 3.3.0.

## Development

```shell
make console     # Start an interactive console
make unit        # Run unit tests
make integration # Run integration tests
make coverage    # Generate test coverage report
make doc         # Generate documentation
make rubocop     # Run RuboCop
```

## Logs

To set the log level:

```shell
LEVEL=0 make unit
LEVEL=0 make console
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
