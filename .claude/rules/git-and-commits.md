# Git and commits

- Conventional Commits: `type(scope): summary` in the imperative, under 72 characters. Types: `feat`,
  `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`. Scopes: `bootstrap`, `network`, `ecr`, `alb`,
  `ecs`, `rds`, `redis`, `secrets`, `iam`, `obs`, `app`, `envs`, `ci`, `docs`.
- One logical change per commit. Do not mix refactoring with behaviour changes.
- Before committing run `./scripts/check.sh` (docs-only changes: the Markdown format check). Never skip
  checks with `--no-verify`.
- Stage explicit paths. Do not commit `docs/superpowers/`, `docs/private/`, `docs/notes/`, `.env*`
  (except `.env.example`), `*.tfstate` or real `*.tfvars`.
- Never push or change anything on GitHub from an agent session; the maintainer pushes.
