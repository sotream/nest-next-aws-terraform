# bootstrap

One-time setup that the rest of the repository depends on. Apply it once, by hand, with credentials of an
administrator of the AWS account.

## What it creates

- **State bucket**: private, versioned, KMS-encrypted S3 bucket with a TLS-only policy and old versions
  expiring after 90 days. State locking uses S3 lock objects (`use_lockfile`), so there is no DynamoDB table.
  The bucket has `prevent_destroy`.
- **GitHub OIDC provider** and three kinds of role. They live under the IAM path `/nnat-ci/`, outside the
  `/nnat/` path the stack's own roles use, so a deploy role cannot edit the CI roles or the boundary:
  - `nnat-ci-plan`: assumable from pull requests of the repository. Read-only on the account plus state
    read and lock; reading secret values is denied explicitly.
  - `nnat-ci-deploy-<env>`: assumable only from a job running in the GitHub Environment of the same name.
    Manages the services the stack uses and can write only its own environment's state. IAM actions are
    limited to roles under `/nnat/`; creating or changing those roles' policies requires the permissions
    boundary below, and the role cannot create or edit managed policies.
  - `nnat-boundary`: the permissions boundary every role created by the stack must carry.
- The deploy role is still broad inside the listed services, because Terraform creates new resources. The
  [security model](../docs/architecture/security-model.md) explains the trade-off.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # then edit the three values
terraform init
terraform apply
```

This first apply uses local state. To move it into the bucket it just created, add this block to a new file
`backend.tf`, then run `terraform init -migrate-state` and delete the local `terraform.tfstate`:

```hcl
terraform {
  backend "s3" {
    bucket       = "<state_bucket output>"
    key          = "bootstrap/terraform.tfstate"
    region       = "<region>"
    use_lockfile = true
    encrypt      = true
  }
}
```

Then store the outputs in GitHub (see [CI/CD](../docs/guides/ci-cd.md)): `plan_role_arn` as the repository
variable `AWS_PLAN_ROLE_ARN`, each entry of `deploy_role_arns` as `AWS_DEPLOY_ROLE_ARN` in the matching
GitHub Environment, and `permissions_boundary_arn` as the variable `PERMISSIONS_BOUNDARY_ARN`.

## Not verified

Never applied. The policies were checked by offline tests and checkov, not by IAM Access Analyzer or a real
workflow run.

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.68 |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| github\_repository | GitHub repository allowed to assume the CI roles, as owner/name. | `string` | n/a | yes |
| state\_bucket\_name | Globally unique name of the S3 bucket that holds the Terraform state. | `string` | n/a | yes |
| environments | Environments that get a deploy role, matching the GitHub Environment names. | `set(string)` | <pre>[<br/>  "dev",<br/>  "stage",<br/>  "prod"<br/>]</pre> | no |
| name\_prefix | Prefix for the CI roles and policies. The deploy role may only manage IAM roles under the path /nnat/. | `string` | `"nnat"` | no |
| region | AWS region for the state bucket. | `string` | `"eu-central-1"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| deploy\_role\_arns | Deploy role ARNs keyed by environment. Store each as AWS\_DEPLOY\_ROLE\_ARN in the matching GitHub Environment. |
| permissions\_boundary\_arn | Boundary the deploy role requires on every role the stack creates. Pass it as permissions\_boundary\_arn. |
| plan\_role\_arn | Role the plan workflow assumes. Store it as the repository variable AWS\_PLAN\_ROLE\_ARN. |
| state\_bucket | Name of the Terraform state bucket; pass it as -backend-config=bucket=... |
<!-- END_TF_DOCS -->
