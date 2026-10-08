# iam

IAM roles for the ECS tasks.

## What it does

- **Execution role** (shared): pulls images from the named ECR repositories, writes to the named log groups
  and reads exactly the named secrets (plus `kms:Decrypt` on the named keys, when given). The one wildcard,
  `ecr:GetAuthorizationToken`, is required by AWS and commented in the code.
- **Task roles**, one per service, with no permissions: the application calls no AWS API. They exist so a
  future permission is granted to one service only.
- Every role lives under the path `/nnat/` and trusts `ecs-tasks.amazonaws.com` for this account only, so the
  CI deploy role can be limited to that path.

## What it does not do

- It does not create the CI roles; those are in `bootstrap/`.
- No ECS Exec permissions: ECS Exec is off.

## Usage

```hcl
module "iam" {
  source          = "../iam"
  name_prefix     = "nnat-dev"
  services        = ["api", "web"]
  secret_arns     = values(module.secrets.secret_arns)
  repository_arns = values(module.ecr.repository_arns)
  log_group_arns  = module.observability.log_group_arns
}
```

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.68 |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| log\_group\_arns | CloudWatch log group ARNs the execution role may write to. | `list(string)` | n/a | yes |
| name\_prefix | Prefix for every role name, for example nnat-dev. | `string` | n/a | yes |
| repository\_arns | ECR repository ARNs the execution role may pull from. | `list(string)` | n/a | yes |
| secret\_arns | Secrets Manager secret ARNs the execution role may read. | `list(string)` | n/a | yes |
| services | Services that get a task role. | `set(string)` | n/a | yes |
| kms\_key\_arns | KMS keys that encrypt the secrets. Leave empty when the AWS-managed key is used. | `list(string)` | `[]` | no |
| permissions\_boundary\_arn | Permissions boundary attached to every role this module creates. Null attaches none. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| execution\_role\_arn | ECS task execution role ARN. |
| task\_role\_arns | Task role ARNs keyed by service. |
<!-- END_TF_DOCS -->
