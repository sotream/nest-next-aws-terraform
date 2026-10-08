# Environments

Three environments share one code path: `envs/dev`, `envs/stage` and `envs/prod`. Each root is one
`module "app"` call to [`modules/app-stack`](../../modules/app-stack/README.md) plus a backend key and a
provider. They differ only in the variable defaults in their `variables.tf` and in the values you give them.

## What differs

| Setting                         | dev                                         | stage                                                                                                                                                                      | prod                                        |
| ------------------------------- | ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `domain_name`                   | optional                                    | required                                                                                                                                                                   | required                                    |
| `APP_ENV` the starter runs with | `dev` without a domain, `prod` with one     | `prod`                                                                                                                                                                     | `prod`                                      |
| `nat_mode`                      | `single`                                    | `single`                                                                                                                                                                   | `per_az`                                    |
| `api_sizing` and `web_sizing`   | 256 CPU, 512 MiB, 1 task                    | 512 CPU, 1024 MiB, 1 task                                                                                                                                                  | 512 CPU, 1024 MiB, 2 tasks                  |
| `rds`                           | `db.t4g.micro`, single-AZ, 7 d backups      | same as dev                                                                                                                                                                | `db.t4g.small`, Multi-AZ, 14 d backups      |
| `redis`                         | `cache.t4g.micro`, no replica, no snapshots | same as dev                                                                                                                                                                | `cache.t4g.small`, 1 replica, 7 d snapshots |
| `deletion_protection`           | `false`                                     | `false`                                                                                                                                                                    | `true`                                      |
| `final_snapshot_on_destroy`     | bool                                        | Take a final database snapshot on destroy; independent of `deletion_protection`. `false` in dev and stage, `true` in prod                                                  |
| `api_health_path`               | string                                      | API target group health path: `/api/health/live` (default) or `/api/health/ready`. See the caveat in the [architecture overview](../architecture/overview.md#request-flow) |
| `log_retention_days`            | 14                                          | 30                                                                                                                                                                         | 90                                          |

## Variables

These exist in every `envs/*/variables.tf`. Set them in `terraform.tfvars` (git-ignored; copy
`terraform.tfvars.example`) or, in CI, through the repository variables described in the
[CI/CD guide](ci-cd.md).

| Variable                   | Type   | Effect                                                                                                           |
| -------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------- |
| `region`                   | string | AWS region; default `eu-central-1`                                                                               |
| `domain_name`              | string | Public domain. Empty serves HTTP on the ALB name (dev only)                                                      |
| `hosted_zone_id`           | string | Route 53 zone holding `domain_name`; required when a domain is set                                               |
| `starter_ref`              | string | Starter commit the images were built from; informational                                                         |
| `services_image_tag`       | string | Image tag of `api` and `web`. Empty creates no services                                                          |
| `migrate_image_tag`        | string | Image tag of the migration task definition. Empty registers none                                                 |
| `credentials_version`      | number | Raise to rotate the database password and Redis token                                                            |
| `jwt_version`              | number | Raise to rotate the JWT secret (signs every user out)                                                            |
| `nat_mode`                 | string | `single` or `per_az`                                                                                             |
| `api_sizing`, `web_sizing` | object | `cpu`, `memory` (MiB), `count`                                                                                   |
| `rds`                      | object | `instance_class`, `multi_az`, `backup_retention_days`                                                            |
| `redis`                    | object | `node_type`, `replicas`, `snapshot_retention_days`                                                               |
| `deletion_protection`      | bool   | Protects RDS and the ALB from deletion                                                                           |
| `log_retention_days`       | number | CloudWatch log retention                                                                                         |
| `alarm_email`              | string | Email for alarms; the recipient must confirm the SNS subscription                                                |
| `permissions_boundary_arn` | string | Boundary for every role the stack creates; required when the deploy role demands one (it does, see `bootstrap/`) |

Change sizing by editing the defaults in `envs/<name>/variables.tf` in a pull request, or override a value
in `terraform.tfvars` for a local plan.

## Domain, `APP_ENV` and HTTPS

The starter's `APP_ENV=prod` requires an https `WEB_ORIGIN`, secure cookies and a strong JWT secret, and
`APP_ENV=dev` allows plain HTTP. The stack therefore decides `APP_ENV` from the domain:

- **With a domain** (any environment): ACM certificate, HTTPS listener, `APP_ENV=prod`, origin
  `https://<domain>`.
- **Without a domain** (only `dev`): HTTP on the ALB's DNS name, `APP_ENV=dev`, origin `http://<alb dns>`.
  The refresh cookie is not `Secure`, Swagger is enabled and credentials travel in clear text. Use it for
  short experiments only.
- `stage` and `prod` without a domain fail the plan with a clear message (`terraform_data.guard`).

The web image is built with `NEXT_PUBLIC_API_URL` set to this same origin, because the ALB serves web and API
from one host. That keeps the starter's same-site cookie rule satisfied.

## Add a fourth environment

1. Copy a root: `cp -R envs/stage envs/qa`.
2. In `envs/qa/backend.tf` change the key to `qa/terraform.tfstate`.
3. In `envs/qa/main.tf` change the `Environment` tag and `environment = "qa"` (2 to 10 lowercase letters or
   digits, starting with a letter).
4. Adjust the variable defaults in `envs/qa/variables.tf`.
5. In `bootstrap/` add `"qa"` to `environments` and apply, to create its deploy role.
6. Create a GitHub Environment named `qa` with `AWS_DEPLOY_ROLE_ARN`, add the `DOMAIN_NAME_QA`,
   `HOSTED_ZONE_ID_QA` variables, and add `qa` to the options in `.github/workflows/deploy.yml` and the matrix
   in `.github/workflows/plan.yml`.
7. Run `./scripts/check.sh`.
