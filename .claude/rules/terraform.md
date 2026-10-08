# Terraform

- Each module has `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, a `README.md` and, where logic
  can be checked offline, `tests/*.tftest.hcl`.
- Every variable has a `description` and a `type`; add `validation` for anything with a closed set or range.
- Every module takes `name_prefix` and never hard-codes an environment name.
- Prefer `for_each` over `count`; use `count` only as an on/off switch (`count = var.x ? 1 : 0`).
- Pin providers (`~> 6.68`) and `required_version`; commit nothing under `.terraform/`.
- Optional behaviour is a variable with a safe default, never a copy of the module.
- Modules do not read each other's internals; `app-stack` connects them through outputs and variables.
- Run `terraform fmt` and `./scripts/check.sh` before every commit.
