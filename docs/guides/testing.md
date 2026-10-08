# Testing

Nothing in this repository needs AWS credentials to be checked. That is also its limit: offline checks prove
the configuration is well-formed and does what the tests say, not that AWS accepts it.

## The quality gate

```bash
./scripts/check.sh
```

For `bootstrap/`, every module and every `envs/*` root it runs, in order:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false` and `terraform validate` (skipped for modules with ephemeral outputs,
   which are not valid root modules; their callers and tests validate them)
3. `tflint` with the pinned AWS ruleset (`.tflint.hcl`)
4. `terraform test` for every directory that has a `tests/` folder

Expected: exit code 0 and a `Success!` line per tested directory. CI runs the same script
(`ci.yml`, job `terraform`). Also run `./scripts/docs.sh` when you change variables or outputs.

## Run one module's tests

```bash
cd modules/alb
terraform init -backend=false
terraform test
terraform test -filter=tests/alb.tftest.hcl      # one file
```

## How the offline tests work

Tests are Terraform test files (`tests/*.tftest.hcl`) that **plan** a module with a **mocked AWS provider**
(`mock_provider "aws" {}`). The mock answers every AWS call with generated values, so no credentials or
network are used, and assertions inspect the planned resources: that the database is private and encrypted,
that the HTTPS listener uses the TLS 1.3 policy, that secrets are `valueFrom` references, that the deploy
role's trust policy names exactly one GitHub environment.

Techniques used in this repository:

- `override_data` and `mock_data` for data sources whose values matter (availability zones) or must be valid
  JSON (IAM policy documents).
- `override_resource` with `override_during = plan` where a computed ARN would otherwise make a policy
  document unknown in the plan (`bootstrap`).
- `expect_failures` to prove that a validation or the `terraform_data.guard` precondition rejects bad input.
- `jsonencode` instead of `aws_iam_policy_document` in the `iam` module so policy statements can be asserted.

## Ephemeral values and the harness

Mock providers cannot serve ephemeral resources, and a module with ephemeral outputs cannot be a root
module. The `secrets` module therefore has a small test-only root, `modules/secrets/tests/harness`, that
calls it and exposes only non-secret outputs. Its tests use an aliased mock AWS provider and the **real**
`random` provider, which needs no network. `app-stack` is tested the same way: AWS mocked, `random` real.

## Add a test to a new module

1. Create `tests/<name>.tftest.hcl` next to the module.
2. Start with `mock_provider "aws" {}` and a `variables {}` block with the required inputs.
3. Write one `run` block per behaviour with `command = plan` and one `assert`. Use `command = apply` only
   against the mock and only when you need computed values; mocked applies produce invalid ARNs for some
   resources.
4. Watch it fail before you write the module code, then make it pass.

## Linting and security scanning

```bash
tflint --init && tflint --chdir=modules/alb
checkov --config-file .checkov.yaml         # needs: pip install checkov
```

`.checkov.yaml` has no skip list on purpose. Each skip is a comment inside the resource
(`#checkov:skip=CKV_AWS_xxx:reason`), so the reason sits next to the code it excuses.

## What is verified offline, and what is not

| Verified offline                                        | Needs a real account                                              |
| ------------------------------------------------------- | ----------------------------------------------------------------- |
| Syntax, types, validation rules, provider schema        | That AWS accepts every argument and combination                   |
| Resource wiring and counts, conditional resources       | Real plans (data sources, existing state, API-side defaults)      |
| Policy statements and trust conditions as written       | That the IAM policies are sufficient and exactly least-privilege  |
| Secret values never appear in plans (write-only schema) | The write-only flow end to end: RDS, ElastiCache, Secrets Manager |
| Workflow YAML syntax (`actionlint`)                     | That the workflows run, assume roles, build, migrate and roll out |
| Mermaid diagrams render                                 | That the starter's images run on Fargate behind this ALB          |
