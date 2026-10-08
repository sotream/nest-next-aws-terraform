#!/usr/bin/env bash
# Offline test for scripts/current-image-tag.sh: a stub `aws` stands in for the real CLI.
set -euo pipefail
cd "$(dirname "$0")/../.."

stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT

cat > "$stub_dir/aws" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *describe-services*) echo "${STUB_TASK_DEFINITION:-None}" ;;
  *describe-task-definition*) echo "${STUB_IMAGE:-}" ;;
  *) echo "unexpected aws call: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$stub_dir/aws"
export PATH="$stub_dir:$PATH"

fail() { echo "FAIL: $1" >&2; exit 1; }

# A running service: the tag of the image its current task definition uses.
got=$(STUB_TASK_DEFINITION=arn:aws:ecs:eu-central-1:1:task-definition/nnat-dev-api:7 \
  STUB_IMAGE=111111111111.dkr.ecr.eu-central-1.amazonaws.com/nnat-dev/api:abc123def456-0a1b2c3d \
  ./scripts/current-image-tag.sh nnat-dev nnat-dev-api)
[ "$got" = "abc123def456-0a1b2c3d" ] || fail "expected the image tag, got '$got'"

# No service yet (first deployment): empty, and success.
got=$(STUB_TASK_DEFINITION=None ./scripts/current-image-tag.sh nnat-dev nnat-dev-api)
[ -z "$got" ] || fail "expected an empty tag for a missing service, got '$got'"

# An image reference without a tag (digest only) must not leak the whole reference.
got=$(STUB_TASK_DEFINITION=arn:x STUB_IMAGE='111.dkr.ecr.eu-central-1.amazonaws.com/nnat-dev/api@sha256:deadbeef' \
  ./scripts/current-image-tag.sh nnat-dev nnat-dev-api)
[ -z "$got" ] || fail "expected an empty tag for a digest reference, got '$got'"

echo "current-image-tag: ok"
