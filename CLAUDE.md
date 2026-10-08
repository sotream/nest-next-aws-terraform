# nest-next-aws-terraform

Terraform that deploys [nest-next-starter](https://github.com/sotream/nest-next-starter) (NestJS API,
Next.js web, PostgreSQL, Redis) to AWS in three environments. A portfolio repository: favour clarity,
small single-purpose modules and honest documentation of what is not verified.

## Stack

Terraform >= 1.11, AWS provider ~> 6.68, tflint, checkov, GitHub Actions with OIDC. Runtime: ECS Fargate,
ALB, RDS PostgreSQL, ElastiCache Redis, Secrets Manager.

## Commands

```bash
./scripts/check.sh                          # fmt, validate, tflint, terraform test (no AWS credentials)
terraform -chdir=envs/dev init -backend=false && terraform -chdir=envs/dev validate
terraform -chdir=modules/<name> test        # one module's offline tests
```

## Architecture in five lines

1. Modules under `modules/` are single-purpose; `modules/app-stack` is the only place that composes them.
2. `envs/dev|stage|prod` hold no resources: one `module "app"` call, a backend key and a provider.
3. Secrets are ephemeral values written through write-only attributes; no secret value is in state.
4. CI assumes AWS roles through GitHub OIDC; there are no long-lived keys.
5. The starter is deployed unmodified; its ADR 0007 (no trust proxy) is a documented limitation here.

More: [architecture](docs/architecture/overview.md), [ADRs](docs/adr), [guides](docs/guides).

## Hard rules

- Never run `terraform apply` or create AWS resources. Never run `git push`.
- Run `./scripts/check.sh` before finishing any task. Do not claim something works without running it.
- Never read or print real tfvars, state files or credentials. Examples hold placeholders only.
- No secret value in variables, outputs, state or logs; use ephemeral resources and write-only attributes.
- Conventional Commits, small changes. Do not commit `docs/superpowers/`, `docs/private/` or `docs/notes/`.
- Comments explain why, not what. Every lint or checkov skip has an inline reason. No module without a
  second use unless it is a boundary named in the spec.

## Where the rules are

`.claude/rules/` (terraform, security, git-and-commits, docs). Contribution checklist:
[CONTRIBUTING.md](CONTRIBUTING.md).
