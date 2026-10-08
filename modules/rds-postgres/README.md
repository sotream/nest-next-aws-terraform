# rds-postgres

A private, encrypted PostgreSQL instance for the application.

## What it does

- RDS PostgreSQL on `gp3` storage with autoscaling, encrypted with a dedicated KMS key (rotation on).
- Private subnets only; the security group admits port 5432 from the listed security groups and nothing else.
- Automated backups, minor-version upgrades, CloudWatch log exports, optional Multi-AZ and deletion protection
  (a protected database takes a final snapshot on destroy).
- The master password is an ephemeral variable sent through `password_wo`; it is never in state. Raise
  `password_version` to send it again.
- Parameter group sets `rds.force_ssl = 1`: every connection must use TLS. The application asks for it with
  `?sslmode=` in `DATABASE_URL` (set by the `secrets` module; see [ADR 0008](../../docs/adr/0008-database-tls.md)).

## What it does not do

- No read replicas, no cross-region backups, no Performance Insights or enhanced monitoring.
- It does not create secrets; see the `secrets` module.

## Usage

```hcl
module "rds" {
  source                     = "../rds-postgres"
  name_prefix                = "nnat-dev"
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.api.security_group_id]
  instance_class             = "db.t4g.micro"
  password                   = module.secrets.db_password
  password_version           = module.secrets.db_password_version
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
| allowed\_security\_group\_ids | Security groups allowed to connect on port 5432. The list length must be known at plan time. | `list(string)` | n/a | yes |
| instance\_class | RDS instance class. | `string` | n/a | yes |
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| password | Master password. Ephemeral: it is sent to AWS and never stored in state. | `string` | n/a | yes |
| password\_version | Raise to send the password again (write-only attributes are not diffed). | `number` | n/a | yes |
| subnet\_ids | Private subnet IDs for the DB subnet group (at least two AZs). | `list(string)` | n/a | yes |
| vpc\_id | VPC the database security group belongs to. | `string` | n/a | yes |
| allocated\_storage | Initial storage in GiB. | `number` | `20` | no |
| backup\_retention\_days | Automated backup retention in days. | `number` | `7` | no |
| db\_name | Initial database name. | `string` | `"app"` | no |
| deletion\_protection | Block deletion of the instance. | `bool` | `false` | no |
| engine\_version | PostgreSQL version. The major version selects the parameter group family. | `string` | `"17"` | no |
| final\_snapshot | Take a final snapshot when the instance is destroyed. Independent of deletion\_protection, which is switched off to destroy. | `bool` | `true` | no |
| max\_allocated\_storage | Storage autoscaling ceiling in GiB. | `number` | `100` | no |
| multi\_az | Run a standby in a second AZ. | `bool` | `false` | no |
| username | Master username. | `string` | `"app"` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| address | Database endpoint address. |
| instance\_id | DB instance identifier, used by alarms. |
| instance\_resource\_id | Immutable RDS resource id; changes whenever the instance is replaced. Feeds the secrets module's db\_generation. |
| kms\_key\_arn | KMS key that encrypts the database. |
| port | Database port. |
| security\_group\_id | Security group of the database. |
<!-- END_TF_DOCS -->
