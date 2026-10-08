# Contributing

Pull requests and issues are welcome but may go unanswered (see [About this project](README.md#about-this-project)).
For anything bigger than a small fix, fork the repository instead.

## Commits

Conventional Commits, checked by review rather than a hook: `type(scope): summary` in the imperative, under
72 characters. Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`. Scopes: `bootstrap`,
`network`, `ecr`, `alb`, `ecs`, `rds`, `redis`, `secrets`, `iam`, `obs`, `app`, `envs`, `ci`, `docs`.
One logical change per commit, for example `feat(alb): add HTTPS listener` or
`fix(rds): require TLS and request it in DATABASE_URL`.

## Before you open a pull request

```bash
./scripts/check.sh      # fmt, validate, tflint, terraform test
./scripts/docs.sh       # regenerate module README tables, then commit them
npx prettier@3.9.9 --check "**/*.md" "**/*.yml" "**/*.yaml" "**/*.json"
```

Never commit state files, real `*.tfvars`, `.env` files or credentials. Never run `terraform apply` as part of
a change to this repository.

## Add a module

1. Create `modules/<name>/` with `versions.tf`, `variables.tf`, `main.tf` and `outputs.tf`.
2. Give every variable a `description` and `type`; add `validation` for closed sets and ranges. Take
   `name_prefix`; never hard-code an environment name.
3. Write `tests/<name>.tftest.hcl` first and watch it fail ([testing guide](docs/guides/testing.md)).
4. Add a hand-written `README.md` (purpose, what it does, what it does not do, usage) with the
   `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` markers, then run `./scripts/docs.sh`.
5. Add a row to the [module reference](docs/reference/modules.md) and wire the module in
   `modules/app-stack` only.
6. Any `checkov:skip` needs a reason in the same comment.

## Decisions

Record architecture decisions in `docs/adr/` with the [template](docs/adr/template.md); supersede an ADR
instead of rewriting it.

To report a vulnerability, see [SECURITY.md](SECURITY.md).
