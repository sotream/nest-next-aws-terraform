# 0004. Terraform state and environment layout

- Status: accepted
- Date: 2026-10-08

## Context

Three environments (dev, stage, prod) must share code, not copies of it, and each needs isolated state. The
state backend must exist before anything else and must not be created by the configuration that uses it.

## Decision

- **State** lives in one S3 bucket created by `bootstrap/` (versioned, KMS-encrypted, public access blocked,
  TLS-only policy). Each environment has its own key (`dev/`, `stage/`, `prod/` `terraform.tfstate`).
  **Locking** uses S3 lock objects (`use_lockfile`, Terraform 1.10 or later), so there is no DynamoDB table
  to create, pay for or lose.
- `bootstrap/` also creates the GitHub OIDC provider, the CI roles and the permissions boundary. It starts on
  local state and migrates into the bucket it created.
- **Layout.** `modules/` holds single-purpose modules; `modules/app-stack` is the only module that composes
  them. Each `envs/<name>/` root is one `module "app"` call plus a backend key and a provider, with the
  environment's sizing as variable defaults. A new environment is a copy of one directory.
- All environments share **one AWS account**, separated by the name prefix `nnat-<env>` and by state key.

## Consequences

- Dev, stage and prod cannot drift in structure; they differ only in variables.
- The backend bucket name is passed at `terraform init`, so no account-specific value is committed.
- One account means a shared service quota pool, one blast radius for the deploy role and no billing
  separation. The growth path is one account per environment: the roots already isolate state, so it needs
  per-account backends, per-account roles from `bootstrap/` and `provider` assume-role settings, but no
  module changes.
- The `prevent_destroy` on the state bucket must be removed deliberately to retire it.
