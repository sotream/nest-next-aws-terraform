# CI/CD

Three GitHub Actions workflows plus a composite action. None was run against a real repository or AWS
account; see [Known limitations](../../README.md#known-limitations).

## Workflows

| Workflow                         | Trigger                      | AWS access                          | What it does                                                                                                                                                                                                                                  |
| -------------------------------- | ---------------------------- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci.yml`                         | push, pull request           | none                                | `terraform` job: `./scripts/check.sh` (fmt, validate, tflint, `terraform test`). `docs`: module README tables are current. `format`: Prettier on Markdown, YAML and JSON. `checkov`: security scan. `secrets`: gitleaks over the full history |
| `plan.yml`                       | pull request                 | OIDC, read-only `plan` role         | `terraform plan` for dev, stage and prod, posts one updated comment per environment with the summary line and the full plan                                                                                                                   |
| `deploy.yml`                     | manual (`workflow_dispatch`) | OIDC, per-environment `deploy` role | Builds and deploys one environment from a pinned starter commit                                                                                                                                                                               |
| `.github/actions/terraform-init` | used by the two above        | n/a                                 | Installs Terraform, assumes the role, runs `terraform init` with the bucket and region                                                                                                                                                        |

`plan.yml` runs `terraform plan -refresh=false`: refreshing the secret versions needs `secretsmanager:GetSecretValue`,
which the plan role is denied on purpose because any pull request runs the workflow with it. Plans show
configuration changes, not drift. It ends with a notice instead of failing when `AWS_PLAN_ROLE_ARN` or `TF_STATE_BUCKET` is not set,
which is what happens on pull requests from forks.

## Variables

There are no GitHub secrets: authentication is OIDC. Everything below is a variable (Settings, Secrets and
variables, Actions, Variables). Names are case-insensitive.

| Variable                                | Scope                                     | Used for                                                  |
| --------------------------------------- | ----------------------------------------- | --------------------------------------------------------- |
| `TF_STATE_BUCKET`                       | repository                                | State bucket (`bootstrap` output `state_bucket`)          |
| `AWS_PLAN_ROLE_ARN`                     | repository                                | Role for `plan.yml` (`bootstrap` output `plan_role_arn`)  |
| `PERMISSIONS_BOUNDARY_ARN`              | repository                                | `bootstrap` output `permissions_boundary_arn`             |
| `AWS_REGION`                            | repository, optional                      | Defaults to `eu-central-1`                                |
| `CREDENTIALS_VERSION`, `JWT_VERSION`    | repository, optional                      | Secret rotation, default 1                                |
| `DOMAIN_NAME_DEV`, `_STAGE`, `_PROD`    | repository                                | Public domain per environment (optional for dev)          |
| `HOSTED_ZONE_ID_DEV`, `_STAGE`, `_PROD` | repository                                | Route 53 zone per environment                             |
| `ALARM_EMAIL_DEV`, `_STAGE`, `_PROD`    | repository, optional                      | Alarm recipient                                           |
| `AWS_DEPLOY_ROLE_ARN`                   | GitHub Environment `dev`, `stage`, `prod` | The matching `bootstrap` output `deploy_role_arns[<env>]` |

The per-environment values are repository variables with an environment suffix, not Environment variables,
because the plan workflow runs without a deployment environment and would not see them.

## Setup order

1. Apply `bootstrap/` by hand ([bootstrap README](../../bootstrap/README.md)).
2. Create the repository variables above from its outputs.
3. Create the GitHub Environments `dev`, `stage` and `prod`. Add required reviewers to `stage` and `prod`.
   Add `AWS_DEPLOY_ROLE_ARN` to each. On **every** Environment, including `dev`, set **Deployment branches
   and tags** to `main` only: the OIDC `sub` names the Environment, not the branch, so without this a
   branch with edited workflow code can deploy with the role.
4. Protect `main` by hand: require pull requests, require the `terraform`, `docs`, `format`, `checkov` and
   `secrets` checks, and block force pushes. The repository does not configure this for you.

## Deploying

Actions, Deploy, Run workflow: choose the environment and paste the full 40-character commit SHA of
`sotream/nest-next-starter` to deploy. Branch and tag names are rejected. To find a SHA:

```bash
git ls-remote https://github.com/sotream/nest-next-starter main
```

The workflow then:

1. **Applies the infrastructure** with the services still on the image tag ECS reports they run now
   (`scripts/current-image-tag.sh`; not a Terraform output, which survives a failed rollout). On the first
   deployment there is none, so no services exist yet.
2. **Builds and pushes** `api` and `web` from the starter at that SHA, tagged `<first 12 characters of the SHA>-<8-character hash of the public origin>`.
   The web image is built with `NEXT_PUBLIC_API_URL` equal to the environment's public origin. ECR tags are
   immutable, so an image that already exists is reused; the origin is part of the tag, so the same commit
   deployed under a new domain builds a new image.
3. **Registers the migration task** for the new image, runs it once, waits for it to stop and **fails the
   workflow if the exit code is not 0**. Services are untouched in that case.
4. **Rolls out the services** with `terraform apply`. The ECS deployment circuit breaker rolls back an
   unhealthy rollout and the apply waits for a steady state.
5. **Smoke-tests** `/api/health/ready` and `/sign-in` on the public origin.

Tick `force_restart` after rotating credentials ([operations](operations.md)).

Expected result: all steps green, then `curl <origin>/api/health/ready` returns a JSON body with
`"status":"ok"`.

## Rolling back

Run the workflow again with the previous commit SHA. Its images are still in ECR (the last 10 are kept), so
the build step is skipped, the migration task runs again (it applies nothing new) and the services roll back
to the old images. This does **not** revert database schema changes; migrations are expected to be
backwards compatible ([ADR 0005](../adr/0005-migrations-one-off-task.md)).

## Concurrency

Deployments of one environment never overlap (`concurrency: deploy-<env>`, no cancellation) and Terraform
state is locked with an S3 lock object.
