Connecting to a Postgres database with Prisma is easy.

## PgBouncer Compatibility

Powervisor pool modes behave the same way as PgBouncer. You should be able to
connect to Powervisor with the exact same connection string as you use for
PgBouncer.

## Named Prepared Statements

Prisma will use named prepared statements to query Postgres by default.

To turn off named prepared statements use `pgbouncer=true` in your connection
string with Prisma.

The `pgbouncer=true` connection string parameter is compatible with Powervisor.

## Prisma Connection Management

Make sure to review the [Prisma connection management guide](https://www.prisma.io/docs/guides/performance-and-optimization/connection-management).
