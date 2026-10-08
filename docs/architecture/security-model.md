# Security model

What is trusted, what protects what, and where the protection stops. Everything here is derived from the
Terraform code and offline tests; none of it has been exercised in a real account.

## Trust boundaries

1. **Internet to ALB.** The only public surface. Ports 80 and 443; with a domain, port 80 redirects to 443.
   Invalid HTTP header fields are dropped.
2. **ALB to tasks.** Plain HTTP inside the VPC. Task security groups accept the task port from the ALB
   security group only.
3. **Tasks to data.** RDS accepts 5432 and ElastiCache 6379 from the `api` and `migrate` task security groups
   only. Neither is publicly accessible.
4. **CI to AWS.** GitHub Actions assumes roles through OIDC. No AWS keys exist in GitHub.
5. **Operator to AWS.** The first `bootstrap/` apply needs an administrator; after that day-to-day changes go
   through the workflows.

## IAM role inventory

The stack's own roles live under the IAM path `/nnat/`, which is the only IAM path the deploy role may manage. The CI roles and the permissions boundary live under `/nnat-ci/`, outside it, so a deploy role cannot edit itself, another deploy role or the boundary.

| Role                          | Trusted principal                                    | Permissions                                                                                                                                                            | Why                                                                                                          |
| ----------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `nnat-<env>-ecs-execution`    | `ecs-tasks.amazonaws.com`, this account only         | Pull from the two ECR repositories, write to the three log groups, read exactly the three secrets, `kms:Decrypt` on the shared key                                     | Lets ECS start tasks and inject secrets. `ecr:GetAuthorizationToken` on `*` is the one wildcard AWS requires |
| `nnat-<env>-task-api`, `-web` | `ecs-tasks.amazonaws.com`, this account only         | None                                                                                                                                                                   | The application calls no AWS API. A future permission is granted to one service                              |
| `nnat-<env>-vpc-flow`         | `vpc-flow-logs.amazonaws.com`                        | Write to the flow log group                                                                                                                                            | VPC flow logs                                                                                                |
| `nnat-ci-plan`                | GitHub OIDC, `repo:<owner>/<repo>:pull_request`      | `ReadOnlyAccess`, read of the state bucket, lock objects, state key decrypt; explicit deny of `secretsmanager:GetSecretValue` (so its plans run with `-refresh=false`) | Plan on pull requests without changing anything                                                              |
| `nnat-ci-deploy-<env>`        | GitHub OIDC, `repo:<owner>/<repo>:environment:<env>` | See below                                                                                                                                                              | Deploys one environment (see the isolation limits below)                                                     |
| `nnat-boundary` (policy)      | n/a                                                  | Ceiling for roles the stack creates: ECR pull, log write, secret read, `kms:Decrypt`                                                                                   | Limits what any role created by CI can ever do                                                               |

### The deploy role

`nnat-ci-deploy-<env>` can be assumed only by a job running in the GitHub Environment of the same name, where
required reviewers are configured for stage and prod. It can:

- manage EC2/VPC, ECS, ECR, load balancing, RDS, ElastiCache, CloudWatch and logs, SNS, Secrets Manager,
  KMS, ACM and Route 53 with resource `*` (Terraform creates resources that have no ARN yet);
- manage IAM **only** on `role/nnat/*`: create roles and put or attach role policies **only** while the
  permissions boundary is attached, never remove a boundary, and never create or edit managed policies;
- create the four service-linked roles ECS, load balancing, RDS and ElastiCache need;
- read and write the Terraform state and lock objects of **its own environment only** (`<env>/terraform.tfstate`),
  and use the state KMS key, which it may not disable, schedule for deletion or re-policy.

That is still broad: within those services it can create, change and delete anything, including
`kms:*` and `secretsmanager:*`. It cannot create IAM users, touch roles outside `/nnat/`, edit the CI roles or the boundary, or raise a
role above the boundary. Narrowing it further means pre-created resource ARNs or per-environment accounts
([ADR 0004](../adr/0004-state-and-environments.md)). `iam:PassRole` is limited to `/nnat/` roles but has no
`iam:PassedToService` condition; adding one is a possible hardening.

**Isolation between environments is weak.** The three deploy roles share one account and the service
permissions above use resource `*`, so the `dev` role can, for example, delete the `prod` database. Only the
state files and the IAM boundary are separated per environment. Tag-based conditions or one account per
environment would fix that; neither is built.

### OIDC trust conditions

Both trust policies require `aud = sts.amazonaws.com` and an exact `sub`. There is no wildcard, so pull
requests and other repositories cannot assume the deploy roles. **The `sub` of a deployment job names the
GitHub Environment, not the branch**, so any branch could run `workflow_dispatch` against an Environment that
has no restriction. Set **Deployment branches: `main` only** on every GitHub Environment, including `dev`, and
require reviewers on `stage` and `prod` ([CI/CD guide](../guides/ci-cd.md#setup-order)). Without that, a branch
with edited workflow code can deploy with the role. The plan role is
reachable from any pull request of this repository, which is why it is read-only and cannot read secret
values.

## Encryption

| Data                 | At rest                                                | In transit                                                                                                                     |
| -------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| Terraform state      | S3 with a dedicated KMS key, versioned                 | TLS-only bucket policy                                                                                                         |
| Database             | RDS storage with a dedicated KMS key                   | `rds.force_ssl = 1`, client uses `sslmode=no-verify` (encrypted, server not verified, [ADR 0008](../adr/0008-database-tls.md)) |
| Redis                | ElastiCache at-rest encryption with the shared KMS key | TLS (`rediss://`) and AUTH token                                                                                               |
| Secrets              | Secrets Manager with the shared KMS key                | AWS API over TLS                                                                                                               |
| Images               | ECR with the shared KMS key                            | TLS                                                                                                                            |
| Logs and alarm topic | CloudWatch Logs and SNS with the shared KMS key        | AWS API over TLS                                                                                                               |
| Browser to ALB       | n/a                                                    | TLS 1.2 and 1.3 policy `ELBSecurityPolicy-TLS13-1-2-2021-06` (domain set); plain HTTP in dev without a domain                  |
| ALB to tasks         | n/a                                                    | Plain HTTP inside the VPC (the starter's containers do not terminate TLS)                                                      |

## Secrets

Generated as ephemeral values and written through write-only attributes, so they never reach state, plans or
CI logs ([ADR 0003](../adr/0003-secrets-handling.md)). They reach the application only as container
environment variables injected by ECS from Secrets Manager. Rotation is a manual version bump.

## Known gaps

- **Shared rate limits.** The API sees the ALB's IP for every request, so rate limits are shared by all
  clients and a request flood is not throttled per client ([ADR 0006](../adr/0006-trust-proxy-behind-alb.md)).
- **No WAF and no ALB access logs** by default; both cost money.
- **Unrestricted egress.** Task security groups allow all outbound traffic through the NAT, because the
  destinations are AWS public endpoints. A proxy or VPC endpoints plus egress rules would tighten that.
- **Database server identity is not verified** (above).
- **No HSTS header.** The starter sends none; the ALB does not add one.
- **Single account.** One blast radius for all three environments.
- **Dev without a domain** is plain HTTP with `APP_ENV=dev` (insecure cookie, Swagger on). Use it only for
  short-lived experiments.
