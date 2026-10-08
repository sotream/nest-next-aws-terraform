# elasticache-redis

A private Redis replication group with TLS and AUTH, used by the API for rate limiting.

## What it does

- Redis OSS replication group in private subnets; the security group admits port 6379 from the listed
  security groups only.
- Encryption in transit (clients connect with `rediss://`) and at rest.
- AUTH token as an ephemeral variable sent through `auth_token_wo`; it is never in state. Raise
  `auth_token_version` to send it again.
- `maxmemory-policy = noeviction`: the starter keeps rate-limit counters in Redis and evicting them would
  silently reset the limits.
- `replicas > 0` adds replicas, Multi-AZ and automatic failover.

## What it does not do

- No cluster mode, no Global Datastore, no backups unless `snapshot_retention_days` is set.
- It does not create the secret holding the URL; see the `secrets` module.

## Usage

```hcl
module "redis" {
  source                     = "../elasticache-redis"
  name_prefix                = "nnat-dev"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.api.security_group_id]
  node_type                  = "cache.t4g.micro"
  auth_token                 = module.secrets.redis_auth_token
  auth_token_version         = module.secrets.redis_token_version
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
| allowed\_security\_group\_ids | Security groups allowed to connect on port 6379. The list length must be known at plan time. | `list(string)` | n/a | yes |
| auth\_token | AUTH token. Ephemeral: it is sent to AWS and never stored in state. | `string` | n/a | yes |
| auth\_token\_version | Raise to send the token again (write-only attributes are not diffed). | `number` | n/a | yes |
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| node\_type | ElastiCache node type. | `string` | n/a | yes |
| subnet\_ids | Private subnet IDs for the cache subnet group. | `list(string)` | n/a | yes |
| vpc\_id | VPC the cache security group belongs to. | `string` | n/a | yes |
| engine\_version | Redis OSS version. | `string` | `"7.1"` | no |
| kms\_key\_arn | Customer-managed KMS key for encryption at rest. Null uses the AWS-managed key. | `string` | `null` | no |
| replicas | Number of replicas. Above zero enables Multi-AZ and automatic failover. | `number` | `0` | no |
| snapshot\_retention\_days | Daily snapshot retention. Zero disables snapshots. | `number` | `0` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| generation\_id | Changes whenever the cache is replaced; feeds the secrets module's redis\_generation. |
| port | Redis port. |
| primary\_endpoint | Primary endpoint address. |
| security\_group\_id | Security group of the cache. |
<!-- END_TF_DOCS -->
