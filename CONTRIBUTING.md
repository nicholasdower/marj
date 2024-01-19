# Contributing

## Setup

Install Ruby >= 2.7.0.

## Logs

To see database or Rails logs when running tests:

```shell
LEVEL=0 make rspec
```

Or in the console:

```shell
LEVEL=0 make console
```

## Using MySQL

By default, SQLite is used when running tests or in the console.

To use MySQL, [install Docker](https://docs.docker.com/get-docker), then:

- Run specs: `make rspec-mysql`
- Start a console: `make console-mysql`
- Start the database: `make mysql-server`
- Start a client: `make mysql-client`

## Using PostgreSQL

By default, SQLite is used when running tests or in the console.

To use PostgreSQL, [install Docker](https://docs.docker.com/get-docker), then:

- Run specs: `make rspec-postgres`
- Start a console: `make console-postgres`
- Start the server: `make postgres-server`
- Start a client: `make postgres-client`
