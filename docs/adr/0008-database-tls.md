# 0008. Database TLS: `sslmode=no-verify`

- Status: proposed
- Date: 2026-10-08

## Context

The starter builds its TypeORM options from `DATABASE_URL` only and sets no `ssl` option. Reading TypeORM
1.1.1 and `pg` 8.23.1 shows that TypeORM passes the whole URL to `pg` as `connectionString`, and `pg` parses
`?sslmode=` from it and lets it override other options. So TLS can be requested from the URL without
changing the starter.

Node does not trust the Amazon RDS certificate authority by default. In `pg` 8, `sslmode=require` is an
alias for `verify-full`, so it would fail with a self-signed certificate error until the RDS CA bundle is
added to the image (`NODE_EXTRA_CA_CERTS`) or passed with `sslrootcert`. The starter's image cannot be
changed here.

## Decision

- RDS parameter group: `rds.force_ssl = 1`. Every connection must use TLS.
- `DATABASE_URL` ends in `?sslmode=no-verify`: the connection is encrypted, but the server certificate is
  not checked.

## Consequences

- Traffic between tasks and RDS is encrypted in transit.
- It is not authenticated: a party that could intercept traffic inside the VPC could impersonate the
  database. The private subnets and security groups are the control for that today.
- Upgrade path: put the RDS CA bundle into the starter's image, set `NODE_EXTRA_CA_CERTS`, and change the
  `secrets` module variable `db_ssl_mode` to `verify-full`. `pg` 9 will change the meaning of `require`; the
  explicit `no-verify` and `verify-full` values are stable across that change.
- Status is `proposed` because this was derived from reading source code and mocked plans and has not been
  tried against a real RDS instance.
