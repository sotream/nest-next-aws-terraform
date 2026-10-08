# Module reference

Each module has its own README with a short description, a usage example and generated input and output
tables (`./scripts/docs.sh`). This page is the map.

| Module                                                                 | Purpose                                                              | Key inputs                                         | Key outputs                                | Used by              |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------ | -------------------- |
| [`network`](../../modules/network/README.md)                           | VPC, public and private subnets, NAT, S3 gateway endpoint, flow logs | `nat_mode`, `az_count`, `cidr`                     | `vpc_id`, subnet ids                       | `app-stack`          |
| [`ecr`](../../modules/ecr/README.md)                                   | Image repositories with lifecycle policy                             | `repositories`, `keep_images`                      | `repository_urls`, `repository_arns`       | `app-stack`          |
| [`alb`](../../modules/alb/README.md)                                   | Load balancer, listeners, target groups, optional ACM and Route 53   | `domain_name`, `hosted_zone_id`, `target_groups`   | `public_origin`, `target_group_arns`       | `app-stack`          |
| [`ecs-service`](../../modules/ecs-service/README.md)                   | One Fargate task definition, optional service and security group     | `image`, `enabled`, `secrets`, `register_with_alb` | `security_group_id`, `task_definition_arn` | `app-stack` (x3)     |
| [`rds-postgres`](../../modules/rds-postgres/README.md)                 | Private, encrypted PostgreSQL                                        | `instance_class`, `multi_az`, ephemeral `password` | `address`, `security_group_id`             | `app-stack`          |
| [`elasticache-redis`](../../modules/elasticache-redis/README.md)       | Private Redis with TLS and AUTH                                      | `node_type`, `replicas`, ephemeral `auth_token`    | `primary_endpoint`                         | `app-stack`          |
| [`secrets`](../../modules/secrets/README.md)                           | Ephemeral passwords and write-only Secrets Manager secrets           | `credentials_version`, `db_host`, `redis_host`     | `secret_arns`, ephemeral `db_password`     | `app-stack`          |
| [`iam`](../../modules/iam/README.md)                                   | ECS execution role and per-service task roles                        | `secret_arns`, `repository_arns`, `log_group_arns` | `execution_role_arn`, `task_role_arns`     | `app-stack`          |
| [`observability-basics`](../../modules/observability-basics/README.md) | Log groups, SNS topic, alarms                                        | `log_groups`, `alarmed_services`, `retention_days` | `log_group_names`, `sns_topic_arn`         | `app-stack`          |
| [`app-stack`](../../modules/app-stack/README.md)                       | Composes all of the above into one environment                       | `environment`, `domain_name`, sizing objects       | `public_origin`, `ecr_repository_urls`     | `envs/*`             |
| [`bootstrap`](../../bootstrap/README.md)                               | State bucket, GitHub OIDC provider, CI roles, permissions boundary   | `github_repository`, `state_bucket_name`           | `state_bucket`, role ARNs                  | applied once by hand |

## Composition rules

- A module has one purpose, typed and validated variables, and outputs for everything a sibling needs.
- Every module takes `name_prefix` and never hard-codes an environment name.
- Modules never read each other's internals. `app-stack` is the only place that connects them.
- Optional behaviour (domain, one NAT per AZ, Multi-AZ, deletion protection) is a variable with a safe
  default, never a second copy of a module.
- Modules with ephemeral outputs (`secrets`) cannot be root modules; their tests plan them through a small
  harness ([testing](../guides/testing.md)).
