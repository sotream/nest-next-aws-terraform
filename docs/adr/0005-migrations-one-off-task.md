# 0005. Migrations as a one-off ECS task

- Status: accepted
- Date: 2026-10-08

## Context

The starter never migrates on startup: schema changes are their own deploy step
(`docs/guides/deployment.md` in the starter). Running them from CI would need a network path to the private
database. Running them inside each service task would race when several tasks start together.

## Decision

Register a **migration task definition** from the API image with the command
`node node_modules/typeorm/cli.js migration:run -d dist/infrastructure/database/data-source.js`, in the
private subnets and with the API's environment and secrets (the starter validates its whole configuration
before any command runs). The deploy workflow:

1. applies the infrastructure with the services still on their current image;
2. builds and pushes the images;
3. registers the migration task for the new image and runs it once with `aws ecs run-task`;
4. fails the deploy, leaving the services untouched, if the task exits non-zero;
5. only then updates the services, waits for a steady state, and smoke-tests the public origin.

## Consequences

- One migration runner, inside the VPC, using the same image and credentials path as the application. Logs
  go to `/nnat-<env>/migrate`.
- Migrations run **before** the new code starts, while the old code is still serving. Every migration must
  therefore be backwards compatible with the previous release (add columns and tables first, remove them in a
  later release).
- A failed migration may be half-applied if it is not transactional; the starter's TypeORM migrations run in
  a transaction by default.
- There is no automatic rollback of schema changes. Rolling back the services (deploy the previous SHA) does
  not revert the schema.
- Two concurrent deployments of one environment are prevented by the workflow's concurrency group.
