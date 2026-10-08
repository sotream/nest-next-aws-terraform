# Security

Design: [secrets ADR](../../docs/adr/0003-secrets-handling.md), [security model](../../docs/architecture/security-model.md).

- Never read, print or commit real tfvars, state or credentials. Examples hold placeholders only.
- Secret values are ephemeral and written through `*_wo` attributes. Do not add `random_password` resources
  or `sensitive` outputs that would put a value in state.
- IAM: name resource ARNs; a wildcard needs a comment explaining why AWS requires it.
- Encrypt at rest and in transit unless an ADR records the exception (database TLS, ADR 0008).
- No public database or cache. Security groups reference other security groups, not CIDR ranges, where possible.
- CI uses GitHub OIDC only. Do not add long-lived access keys or secrets for AWS.
- Every `checkov:skip` states why the check does not apply.
