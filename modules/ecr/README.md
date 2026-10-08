# ecr

Container image repositories for the application services.

## What it does

- One repository per name in `repositories` (default `api` and `web`), named `<name_prefix>/<name>`.
- Immutable tags and scan-on-push: a tag always refers to the same image, and deploys tag images with the
  commit SHA of the starter they were built from.
- A lifecycle policy that keeps the latest `keep_images` images.
- Optional KMS encryption through `kms_key_arn`.

## What it does not do

- No cross-account or cross-region replication, no pull-through cache.
- It never deletes a repository that still holds images (`force_delete = false`); empty it before destroy.

## Usage

```hcl
module "ecr" {
  source      = "../ecr"
  name_prefix = "nnat-dev"
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
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| keep\_images | Number of most recent images kept per repository. | `number` | `10` | no |
| kms\_key\_arn | Customer-managed KMS key for image encryption. Null uses the AWS-managed ECR key. | `string` | `null` | no |
| repositories | Repository short names. Each becomes <name\_prefix>/<name>. | `set(string)` | <pre>[<br/>  "api",<br/>  "web"<br/>]</pre> | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| repository\_arns | Repository ARNs keyed by short name. |
| repository\_urls | Repository URLs keyed by short name. |
<!-- END_TF_DOCS -->
