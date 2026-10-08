# secrets

Generates the application secrets and stores them in Secrets Manager without any value reaching Terraform
state.

## What it does

- Opens three `ephemeral "random_password"` values per run: database password, Redis AUTH token, JWT secret.
- Writes three secrets (`database-url`, `redis-url`, `jwt-access-secret`) with `secret_string_wo`.
- Exposes the database password and Redis token as **ephemeral outputs** for the `rds-postgres` and
  `elasticache-redis` modules, plus the matching `*_version` numbers.

## What it does not do

- No automatic rotation. Rotate by raising `credentials_version` (database and Redis) or `jwt_version`.
- It is not a valid root module (ephemeral outputs); call it from another module.

## Usage

```hcl
module "secrets" {
  source      = "../secrets"
  name_prefix = "nnat-dev"
  db_host          = module.rds.address
  db_generation    = module.rds.instance_resource_id
  redis_host       = module.redis.primary_endpoint
  redis_generation = module.redis.generation_id
}
```

## Testing

`terraform test` plans the module through `tests/harness`, with a mocked AWS provider and the real `random`
provider (mock providers cannot serve ephemeral resources).

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.68 |
| random | ~> 3.7 |

### Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| db\_generation | Value that changes whenever the database instance is replaced (for example its resource id). A replacement under the same name keeps the same host, so the host cannot signal it. | `string` | n/a | yes |
| db\_host | Database endpoint address. | `string` | n/a | yes |
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| redis\_generation | Value that changes whenever the cache is replaced (see the elasticache-redis module output generation\_id). | `string` | n/a | yes |
| redis\_host | Redis primary endpoint address. | `string` | n/a | yes |
| credentials\_version | Bump to rotate the database password and the Redis token. Write-only attributes are only sent when their version changes. | `number` | `1` | no |
| db\_name | Database name placed in the DATABASE\_URL secret. | `string` | `"app"` | no |
| db\_port | Database port. | `number` | `5432` | no |
| db\_ssl\_mode | sslmode added to DATABASE\_URL. no-verify encrypts without checking the server certificate (Node does not trust the RDS CA by default); verify-full needs the RDS CA bundle in the image. | `string` | `"no-verify"` | no |
| db\_username | Database user placed in the DATABASE\_URL secret. | `string` | `"app"` | no |
| jwt\_version | Bump to rotate the JWT access secret. Rotating it signs every user out. | `number` | `1` | no |
| kms\_key\_arn | Customer-managed KMS key for the secrets. Null uses the AWS-managed Secrets Manager key. | `string` | `null` | no |
| redis\_port | Redis port. | `number` | `6379` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| database\_url\_query | Query string appended to DATABASE\_URL (not secret); exposed so tests can check it. |
| database\_url\_secret\_version | Version of the DATABASE\_URL secret: credentials\_version plus a hash of db\_generation. |
| db\_password | Ephemeral database password for the rds-postgres module. |
| db\_password\_version | Version to pass as password\_wo\_version: credentials\_version. |
| redis\_auth\_token | Ephemeral Redis AUTH token for the elasticache-redis module. |
| redis\_token\_version | Version to pass as auth\_token\_wo\_version: credentials\_version. |
| redis\_url\_secret\_version | Version of the REDIS\_URL secret: credentials\_version plus a hash of redis\_generation. |
| secret\_arns | Secret ARNs keyed by the container environment variable they feed. |
<!-- END_TF_DOCS -->
