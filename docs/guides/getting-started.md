# Getting started

This guide takes you from a fresh clone to a first plan and, if you choose, a first deployment in your own
AWS account. The author never ran the AWS steps; the commands are written from the code and the tools'
documentation. Expect to fix small things.

## What you need

- Terraform 1.11 or later (`terraform version`). The write-only secrets need it.
- `tflint` and optionally `checkov` and `terraform-docs` to run the quality gate.
- For a real deployment: an AWS account with administrator access for the one-time bootstrap, the AWS CLI,
  a GitHub repository (a fork of this one), and a Route 53 hosted zone if you want a domain. `stage` and
  `prod` need a domain; `dev` can run without one over plain HTTP.

## 1. Check the repository without AWS

```bash
./scripts/check.sh
```

Expected: `terraform fmt`, `validate`, `tflint` and the offline `terraform test` runs finish with exit code 0. This needs no credentials.

## 2. Create the state bucket and CI roles (once)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars    # edit: region, github_repository, state_bucket_name
terraform init
terraform plan
terraform apply
```

The bucket name must be globally unique. Expected: a plan with about 20 resources (bucket and its settings,
KMS key, OIDC provider, plan role, boundary and deploy policy, three deploy roles). Note the outputs:
`state_bucket`, `plan_role_arn`, `deploy_role_arns`, `permissions_boundary_arn`. Then move the bootstrap
state into the new bucket as described in the [bootstrap README](../../bootstrap/README.md).

## 3. Plan an environment

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars    # edit: region, domain (optional in dev), alarm email
terraform init \
  -backend-config="bucket=<state_bucket>" \
  -backend-config="region=<region>"
terraform plan -var "permissions_boundary_arn=<permissions_boundary_arn>"
```

The example file holds placeholders only; real `terraform.tfvars` files are git-ignored. Expected: a plan
that creates the network, ECR repositories, load balancer, database, cache, secrets, IAM roles, cluster,
log groups and alarms, but **no ECS services and no migration task**: both image tags are empty, which is the
first-deployment state.

`stage` and `prod` fail the plan with `stage and prod need domain_name` until you set `domain_name` and
`hosted_zone_id`.

## 4. Deploy

Deploying is done by the workflow, not by a local apply, because it builds the images and runs the
migration between two applies.

1. Push your fork to GitHub.
2. Create the repository variables and GitHub Environments listed in the [CI/CD guide](ci-cd.md#variables).
3. Find a starter commit: `git ls-remote https://github.com/sotream/nest-next-starter main`.
4. Run **Deploy** (Actions tab, Run workflow): choose `dev` and paste the full SHA.
5. When it ends green, open the public origin printed by `terraform output public_origin` (or the load
   balancer's DNS name in dev without a domain) and the sign-in page should load. Create the first user through
   your own reviewed process: the starter's seed users do not exist in `APP_ENV=prod`.

Expected for step 4: infrastructure applies, two images are pushed, the migration task exits with 0, the
services reach a steady state and the smoke test prints a JSON body from `/api/health/ready`.

## 5. Destroy

Read [how to destroy](cost-estimate.md#how-to-destroy) and the [operations runbook](operations.md#destroy-an-environment)
before you start, and destroy `dev` when you are done: it costs roughly 120 USD a month while it exists.

## Next

- [Architecture overview](../architecture/overview.md)
- [Environments](environments.md)
- [Operations runbook](operations.md)
- [Troubleshooting](troubleshooting.md)
