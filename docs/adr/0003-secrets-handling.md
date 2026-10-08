# 0003. Secrets handling

- Status: accepted
- Date: 2026-10-08

## Context

The application needs a database URL with a password, a Redis URL with an AUTH token and a JWT access
secret. The starter refuses to start in `APP_ENV=prod` with defaults. Terraform normally stores generated
passwords in state, which then becomes the most sensitive file in the project.

## Decision

Generate every secret as an **ephemeral resource** (`ephemeral "random_password"`) and send it to AWS only
through **write-only attributes**: `password_wo` on the database, `auth_token_wo` on ElastiCache and
`secret_string_wo` on Secrets Manager. None of these values is stored in state or in a plan file. This needs
Terraform 1.11 or later and AWS provider 6.x.

- Secrets Manager holds three secrets per environment: `database-url`, `redis-url`, `jwt-access-secret`. ECS
  injects them as container secrets; the execution role may read exactly those ARNs.
- Write-only values are not diffed, so they change only when their `*_version` changes. One
  `credentials_version` drives the database password and the Redis token. The URL secrets add a hash of a
  **generation id** to their version (the RDS resource id, and a `terraform_data` that is replaced together
  with the cache), so a replaced database or cache rewrites its URL in the same apply that creates it with a
  new password. The host cannot serve for this: an instance replaced under the same name keeps its endpoint.
  The JWT secret has its own `jwt_version`.
- **Rotation is manual**: raise the version and deploy. Rotating the database or Redis credentials does not
  restart anything by itself, because the task definition is unchanged: run the deploy workflow with
  `force_restart` (ECS reads secrets at task start). While the old Redis token is still held by running tasks
  it keeps working, because ElastiCache rotates tokens with the default `ROTATE` strategy and does not
  revoke the previous one until it is replaced; rotating the JWT secret signs every user out. Automatic rotation with a Lambda is not built
  and the matching checkov rule is skipped with a comment.
- The database URL ends in `?sslmode=no-verify` ([ADR 0008](0008-database-tls.md)).

## Consequences

- State, plan output and CI logs contain no secret values. State still holds secret names, ARNs and
  endpoints, so it stays encrypted and access-controlled ([ADR 0004](0004-state-and-environments.md)).
- Terraform cannot read the secrets back, which is intended; to see a value use the AWS console or CLI with
  the right permissions.
- If a version is raised in only one place the secret and its consumer drift apart; that is why the versions
  derive from one variable and are covered by offline tests.
- The flow was checked against the provider schema and mocked plans, never applied to a real account.
