#!/usr/bin/env bash
# Regenerates the input and output tables between the terraform-docs markers in every module README.
# `./scripts/docs.sh --check` fails when a README is out of date instead of rewriting it.
set -euo pipefail
cd "$(dirname "$0")/.."

check=""
if [ "${1:-}" = "--check" ]; then
  check="--output-check"
fi

for d in bootstrap modules/*; do
  [ -f "$d/README.md" ] || continue
  # $check is intentionally unquoted: empty means no argument.
  # shellcheck disable=SC2086
  terraform-docs $check --config .terraform-docs.yml "$d" >/dev/null
done
echo "docs: ok ${check}"
