# 0001. ECS Fargate over EKS, App Runner and EC2

- Status: accepted
- Date: 2026-10-08

## Context

The workload is two small stateless HTTP services (NestJS API, Next.js web) built from Dockerfiles, plus
PostgreSQL and Redis. Nobody should have to patch a host or operate a control plane. The services need
private networking to RDS and ElastiCache, one public entry point, and a way to run a migration as a
one-off job ([ADR 0005](0005-migrations-one-off-task.md)).

## Decision

Run both services on **ECS with the Fargate launch type**, behind one Application Load Balancer that routes
`/api/*` to the API and everything else to the web app.

Alternatives considered:

- **EKS.** Adds a control plane fee, node management or Karpenter, an ingress controller, IAM roles for
  service accounts and a second deployment tool. Worth it for dozens of services or Kubernetes-native
  tooling; not for two services.
- **App Runner.** The simplest to operate, but it routes one service per URL, so `/api/*` and `/` would need
  two services, two domains and the cookie and origin rules from the starter's deployment guide would break
  (same-site requirement). Reaching a private RDS needs a VPC connector, and there is no one-off task
  primitive for migrations.
- **EC2 (with or without ECS).** Cheapest per vCPU at scale, but brings patching, AMIs, capacity and scaling
  of hosts. Not justified at this size.

## Consequences

- No hosts to manage; each task has its own ENI and security group, so the database can allow exactly the
  API and migration tasks.
- Fargate costs more per vCPU than EC2 and bills per second with a one-minute minimum; at 0.25 to 0.5 vCPU
  per task the absolute cost is small (see [cost estimate](../guides/cost-estimate.md)).
- The ECS deployment circuit breaker gives automatic rollback without extra tooling.
- The Next.js standalone server writes to `.next/cache`, so tasks keep a writable root filesystem and the
  matching checkov rule is not enforced.
- Moving to EKS later is possible because the images and the ALB routing do not depend on ECS.
