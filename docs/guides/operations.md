# Operations runbook

Procedures for a running environment. They were written from the code, not rehearsed on a real account.
Replace `dev` with `stage` or `prod` and the examples use the default region; names follow
`nnat-<env>` (cluster `nnat-dev`, services `nnat-dev-api` and `nnat-dev-web`).

## First deployment

Follow [Getting started](getting-started.md). In short: bootstrap, set the GitHub variables, run the deploy
workflow with a starter commit SHA. The first run applies the infrastructure with no services, builds and
pushes the images, runs the migration and then creates the services.

## Routine deployment

Run the deploy workflow ([CI/CD](ci-cd.md#deploying)). Watch the migration step: a failure there leaves the
running version untouched.

## Roll back

Run the deploy workflow with the previous starter SHA ([CI/CD](ci-cd.md#rolling-back)).

Emergency, if the workflow cannot run: point a service at the previous task definition revision.

```bash
aws ecs update-service --cluster nnat-dev --service nnat-dev-api \
  --task-definition nnat-dev-api:<previous revision>
```

Terraform will revert this on its next apply, so follow up with the workflow.

## Run a migration by hand

```bash
CLUSTER=nnat-dev
TASK_DEF=$(terraform -chdir=envs/dev output -raw migrate_task_definition_arn)
SUBNETS=$(terraform -chdir=envs/dev output -json private_subnet_ids | jq -r 'join(",")')
SG=$(terraform -chdir=envs/dev output -raw migrate_security_group_id)
aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE --task-definition "$TASK_DEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=DISABLED}"
```

Expected: a task ARN. Read the result in the log group `/nnat-dev/migrate` and with
`aws ecs describe-tasks --cluster nnat-dev --tasks <arn> --query 'tasks[0].containers[0].exitCode'`, which
must be `0`.

## Rotate credentials

Secrets are read when a task starts, and rotating changes secrets without changing task definitions, so
the services must be restarted.

1. Raise `CREDENTIALS_VERSION` (database password and Redis token) or `JWT_VERSION` (JWT secret) in the
   repository variables.
2. Run the deploy workflow with the **same** starter SHA and `force_restart` ticked.
3. Expected effect: the database password and Redis token change in place and the URL secrets are rewritten,
   then both services restart. Expect a short burst of errors between the password change and the restart
   (existing database connections keep working; new ones from old tasks fail). Rotating the JWT secret
   invalidates every session: users sign in again.

## Scale a service

Edit `api_sizing` or `web_sizing` in `envs/<name>/variables.tf` (task count, CPU, memory), merge, then run
the deploy workflow. A task count change alone does not need a new image, but the workflow is the supported
path. Valid Fargate CPU and memory pairs are listed in the AWS documentation.

## Read logs

```bash
aws logs tail /nnat-dev/api --follow
aws logs tail /nnat-dev/migrate --since 1h
```

CloudWatch Logs Insights, on the log group `/nnat-dev/api` (the starter logs pino JSON; level 50 is
`error`):

```
fields @timestamp, level, msg
| filter level >= 50
| sort @timestamp desc
| limit 50
```

5xx responses at the load balancer show up as alarms (below), not in these logs.

## Alarms

All alarms publish to the SNS topic `nnat-<env>-alarms`.

| Alarm                                      | Means                                                     | First three checks                                                                     |
| ------------------------------------------ | --------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `...-alb-5xx`                              | The ALB itself returned 5xx (no healthy target, capacity) | Target health in the console; running task count; recent deployment                    |
| `...-api-target-5xx`, `...-web-target-5xx` | The tasks returned 5xx                                    | Logs Insights query above; recent deployment; database and Redis health                |
| `...-<svc>-cpu-high`, `...-memory-high`    | Sustained above 80 percent                                | Traffic; a hot loop in the logs; raise the sizing                                      |
| `...-<svc>-tasks-below-desired`            | Fewer running tasks than desired                          | `aws ecs describe-services` events; image pull or secret errors; health check failures |
| `...-rds-storage-low`                      | Under 5 GiB free                                          | Table growth; storage autoscaling ceiling (`max_allocated_storage`, 100 GiB)           |
| `...-rds-cpu-high`                         | Database CPU above 80 percent                             | Slow queries; instance class                                                           |

The task-count alarm needs Container Insights, which the cluster enables.

## Restore the database

RDS keeps automated backups for 7 days (dev, stage) or 14 days (prod), and a final snapshot is taken on
destroy when `final_snapshot_on_destroy` is true (the default in prod). The `rds-postgres` module cannot restore from a snapshot, and
the connection secret is write-only, so a restore is a manual cut-over:

1. Restore to a **new** instance (`aws rds restore-db-instance-to-point-in-time` or
   `restore-db-instance-from-db-snapshot`) in the same subnet group and security group.
2. Verify it, then replace the live instance's data path: change the application's `DATABASE_URL` secret to
   the new endpoint in the console and restart the services, or import the new instance into Terraform.
3. Treat Terraform as out of sync until you reconcile it.

This procedure has not been rehearsed. For a demo environment, destroying and recreating is faster.

## Destroy an environment

1. In `envs/<name>/variables.tf` (or tfvars) set `deletion_protection = false` and apply, so the database
   and load balancer can be deleted. Prod only. Leave `final_snapshot_on_destroy = true` if you want a last
   snapshot; it is independent of deletion protection, and the snapshot name carries the creation time.
2. Empty the ECR repositories (they are not force-deleted):
   `aws ecr batch-delete-image --repository-name nnat-dev/api --image-ids "$(aws ecr list-images --repository-name nnat-dev/api --query 'imageIds[*]' --output json)"`,
   and the same for `nnat-dev/web`.
3. `terraform -chdir=envs/dev destroy`.
4. Secrets are scheduled for deletion with a 7-day recovery window, so the names stay reserved. To recreate
   the environment sooner:
   `aws secretsmanager delete-secret --secret-id nnat-dev/database-url --force-delete-without-recovery`
   (and `redis-url`, `jwt-access-secret`).
5. KMS keys enter a 30-day deletion window and cost a little until then.
6. Retire `bootstrap/` last, after all environments: remove `prevent_destroy` from the state bucket
   deliberately and empty it first.

See the [cost estimate](cost-estimate.md#how-to-destroy) for what keeps costing money if you skip a step.
