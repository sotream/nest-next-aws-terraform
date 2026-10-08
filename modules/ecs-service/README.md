# ecs-service

One Fargate workload: a task definition, optionally an ECS service, and the security group around them.
`app-stack` uses it three times: `api`, `web` and `migrate` (a task definition with no service, started once
by the deploy workflow).

## What it does

- Fargate task (`awsvpc`, no public IP) with one container, awslogs logging and an optional health check.
- Secrets are injected as `valueFrom` Secrets Manager ARNs; they never appear as plain environment values.
- Service with a deployment circuit breaker that rolls back, and `wait_for_steady_state` so an apply fails
  when the rollout does.
- With `register_with_alb` the service is attached to a target group and its security group admits the port
  from the load balancer's security group only.
- `enabled = false` plans nothing. This is how a new environment starts before the first image exists.

## What it does not do

- No autoscaling, no ECS Exec, no sidecars, no read-only root filesystem (the Next.js standalone server writes
  to `.next/cache`).
- It does not create the cluster, roles or log groups; pass them in.

## Usage

```hcl
module "api" {
  source                = "../ecs-service"
  name_prefix           = "nnat-dev"
  name                  = "api"
  enabled               = var.services_image_tag != ""
  cluster_arn           = aws_ecs_cluster.this.arn
  image                 = "${module.ecr.repository_urls["api"]}:${var.services_image_tag}"
  cpu                   = 256
  memory                = 512
  port                  = 4000
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arns["api"]
  subnet_ids            = module.network.private_subnet_ids
  vpc_id                = module.network.vpc_id
  log_group_name        = module.observability.log_group_names["api"]
  register_with_alb     = true
  target_group_arn      = module.alb.target_group_arns["api"]
  alb_security_group_id = module.alb.security_group_id
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
| cluster\_arn | ECS cluster ARN. | `string` | n/a | yes |
| cpu | Task CPU units (256, 512, 1024, ...). | `number` | n/a | yes |
| enabled | Plan the task definition and service. False before the first image exists. | `bool` | n/a | yes |
| execution\_role\_arn | Task execution role ARN. | `string` | n/a | yes |
| image | Full image URI including the tag. | `string` | n/a | yes |
| log\_group\_name | CloudWatch log group the container writes to. | `string` | n/a | yes |
| memory | Task memory in MiB. | `number` | n/a | yes |
| name | Short service name: api, web or migrate. | `string` | n/a | yes |
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| port | Container port. Zero for tasks that serve nothing. | `number` | n/a | yes |
| subnet\_ids | Private subnets for the tasks. | `list(string)` | n/a | yes |
| task\_role\_arn | Task role ARN. | `string` | n/a | yes |
| vpc\_id | VPC of the tasks. | `string` | n/a | yes |
| alb\_security\_group\_id | Load balancer security group allowed to reach the task port. Used when register\_with\_alb is true. | `string` | `null` | no |
| command | Container command override. Empty keeps the image default. | `list(string)` | `[]` | no |
| create\_service | Create an ECS service. False for one-off tasks such as migrations (task definition only). | `bool` | `true` | no |
| desired\_count | Number of running tasks. | `number` | `1` | no |
| environment | Plain environment variables. | `map(string)` | `{}` | no |
| health\_check\_grace\_period\_seconds | Seconds ECS ignores failing load balancer health checks after a task starts. | `number` | `60` | no |
| health\_command | Container health check command without the CMD prefix. Empty disables it. | `list(string)` | `[]` | no |
| register\_with\_alb | Attach the service to a load balancer target group. A plain bool because the target group ARN is unknown at plan time. | `bool` | `false` | no |
| secrets | Container secrets: environment variable name to Secrets Manager ARN. | `map(string)` | `{}` | no |
| target\_group\_arn | Target group ARN. Used when register\_with\_alb is true. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| security\_group\_id | Security group of the tasks; the database and cache allow ingress from it. |
| service\_name | ECS service name, or null when no service is created. |
| task\_definition\_arn | Task definition ARN, or null when the module is disabled. |
<!-- END_TF_DOCS -->
