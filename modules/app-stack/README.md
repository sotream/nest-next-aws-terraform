# app-stack

The composition of one environment: the only module an `envs/*` root calls. It connects every other module
and holds the rules that depend on more than one of them.

## What it creates

Network, ECR repositories, the ALB, a shared KMS key, the secrets, RDS PostgreSQL, ElastiCache Redis,
logging and alarms, IAM roles, an ECS cluster, the `api` and `web` services and the `migrate` task
definition.

## Rules it enforces

- **Domain rule.** `stage` and `prod` need `domain_name`; the plan fails otherwise (`terraform_data.guard`).
  `dev` may run without one, over HTTP, as `APP_ENV=dev`. With a domain every environment runs
  `APP_ENV=prod` over HTTPS. The reasons are in the starter's deployment guide.
- **One origin.** The ALB sends `/api/*` to the API and everything else to the web app, so `WEB_ORIGIN` and
  `NEXT_PUBLIC_API_URL` are the same value, `public_origin`.
- **Staged rollout.** Empty `services_image_tag` creates no services; empty `migrate_image_tag` registers no
  migration task. The deploy workflow sets `migrate_image_tag` first, runs the migration, then sets
  `services_image_tag` ([ADR 0005](../../docs/adr/0005-migrations-one-off-task.md)).
- **Same environment for migrations.** The migration task gets the API's environment and secrets because the
  starter validates its whole configuration before running any command.

## What it does not do

- It never builds or pushes images; the deploy workflow does.
- It does not create the state bucket or CI roles; see `bootstrap/`.
- Kafka is off (`KAFKA_ENABLED=false`); see [ADR 0007](../../docs/adr/0007-kafka-on-aws.md).

## Usage

```hcl
module "app" {
  source      = "../../modules/app-stack"
  environment = "prod"
  domain_name = "app.example.com"
  hosted_zone_id = "Z0000000000000000000"
}
```

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
| environment | Environment name (dev, stage, prod). Used in resource names and decides the domain rule. | `string` | n/a | yes |
| alarm\_email | Email address for alarms. Empty creates no subscription. | `string` | `""` | no |
| api\_health\_path | Health path of the API target group. /api/health/live (default) does not touch dependencies, so a database or Redis outage does not make ECS restart API tasks. /api/health/ready (database and Redis) takes an unready task out of the load balancer, but ECS also replaces tasks the load balancer reports unhealthy, so an outage makes ECS restart every API task. | `string` | `"/api/health/live"` | no |
| api\_sizing | API task CPU units, memory MiB and task count. | <pre>object({<br/>    cpu    = number<br/>    memory = number<br/>    count  = number<br/>  })</pre> | <pre>{<br/>  "count": 1,<br/>  "cpu": 256,<br/>  "memory": 512<br/>}</pre> | no |
| credentials\_version | Raise to rotate the database password and the Redis AUTH token. | `number` | `1` | no |
| deletion\_protection | Protect the database and the load balancer from deletion (and take a final database snapshot). | `bool` | `false` | no |
| domain\_name | Public domain name. Required for every environment except dev; empty serves dev over HTTP on the load balancer DNS name. | `string` | `""` | no |
| final\_snapshot\_on\_destroy | Take a final database snapshot when the database is destroyed. Keep it true wherever the data matters; it is separate from deletion\_protection, which is switched off to destroy. | `bool` | `true` | no |
| hosted\_zone\_id | Route53 hosted zone that holds domain\_name. | `string` | `""` | no |
| jwt\_version | Raise to rotate the JWT access secret (signs every user out). | `number` | `1` | no |
| log\_retention\_days | CloudWatch log retention. | `number` | `14` | no |
| migrate\_image\_tag | Image tag of the migration task definition. Empty registers none. | `string` | `""` | no |
| nat\_mode | single or per\_az; see the network module. | `string` | `"single"` | no |
| permissions\_boundary\_arn | Permissions boundary attached to every role in the stack. Null attaches none. | `string` | `null` | no |
| rds | Database sizing. | <pre>object({<br/>    instance_class        = string<br/>    multi_az              = bool<br/>    backup_retention_days = number<br/>  })</pre> | <pre>{<br/>  "backup_retention_days": 7,<br/>  "instance_class": "db.t4g.micro",<br/>  "multi_az": false<br/>}</pre> | no |
| redis | Cache sizing. | <pre>object({<br/>    node_type               = string<br/>    replicas                = number<br/>    snapshot_retention_days = number<br/>  })</pre> | <pre>{<br/>  "node_type": "cache.t4g.micro",<br/>  "replicas": 0,<br/>  "snapshot_retention_days": 0<br/>}</pre> | no |
| services\_image\_tag | Image tag the api and web services run. Empty creates no services (first deployment). | `string` | `""` | no |
| starter\_ref | Commit SHA of nest-next-starter the images were built from. Informational; echoed in outputs. | `string` | `""` | no |
| web\_sizing | Web task CPU units, memory MiB and task count. | <pre>object({<br/>    cpu    = number<br/>    memory = number<br/>    count  = number<br/>  })</pre> | <pre>{<br/>  "count": 1,<br/>  "cpu": 256,<br/>  "memory": 512<br/>}</pre> | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| alb\_dns\_name | DNS name of the load balancer. |
| app\_env | APP\_ENV the starter runs with: prod when a domain is set, dev otherwise. |
| cluster\_name | ECS cluster name. |
| ecr\_repository\_urls | ECR repository URLs keyed by api and web. |
| migrate\_security\_group\_id | Security group of the migration task. |
| migrate\_task\_definition\_arn | Migration task definition ARN, or null until migrate\_image\_tag is set. |
| private\_subnet\_ids | Private subnet IDs, for run-task network configuration. |
| public\_origin | Origin users open; also WEB\_ORIGIN and the NEXT\_PUBLIC\_API\_URL the web image is built with. |
| services\_image\_tag | Image tag the services currently run. |
| starter\_ref | Starter commit the running images were built from, as last recorded. |
<!-- END_TF_DOCS -->
