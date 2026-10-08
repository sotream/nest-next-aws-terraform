#!/usr/bin/env bash
# Offline quality gate shared by developers and CI. Needs no AWS credentials.
set -euo pipefail
cd "$(dirname "$0")/.."

terraform fmt -check -recursive

# Directories that do not exist yet are skipped, so the script also runs on a partial checkout. Test
# harnesses under tests/ are planned by `terraform test`, not checked on their own.
dirs=$(find bootstrap modules envs -name '*.tf' -not -path '*/.terraform/*' -not -path '*/tests/*' -exec dirname {} \; 2>/dev/null | sort -u || true)

tflint --init >/dev/null
for d in $dirs; do
  echo "== $d"
  terraform -chdir="$d" init -backend=false -input=false >/dev/null
  # A module with ephemeral outputs is not valid as a root module; its callers and its tests validate it.
  if ! grep -qs 'ephemeral *= *true' "$d"/outputs.tf; then
    terraform -chdir="$d" validate
  fi
  tflint --chdir="$d"
  if [ -d "$d/tests" ]; then
    terraform -chdir="$d" test
  fi
done
