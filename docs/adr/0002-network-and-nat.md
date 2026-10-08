# 0002. Network layout and the NAT cost trade-off

- Status: accepted
- Date: 2026-10-08

## Context

Tasks, the database and the cache must not be reachable from the internet, but tasks need to reach ECR,
Secrets Manager and CloudWatch Logs (public AWS endpoints). A NAT gateway costs about 38 USD a month per
gateway (price list, eu-central-1, approximate) plus data processing, which is the largest fixed cost in the
dev environments.

## Decision

- One VPC per environment, two availability zones, one public and one private subnet per zone. The ALB lives
  in the public subnets; tasks, RDS and ElastiCache in the private ones. Tasks get no public IPs.
- Egress goes through NAT gateways. `nat_mode = single` shares one gateway (dev and stage);
  `nat_mode = per_az` creates one per zone (prod).
- Add the free S3 **gateway** endpoint so ECR layer downloads, which are served from S3, bypass the NAT.
- Do not add interface endpoints. ECR API, ECR DKR, Logs and Secrets Manager would be four endpoints in two
  zones, roughly 8 USD per endpoint and zone per month: more than one NAT gateway at this traffic level. They
  pay off when NAT data charges or the security requirement (no internet egress) outweigh that fixed cost.

## Consequences

- With `single`, an outage of the NAT's zone stops outbound traffic from tasks in the other zone: no image
  pulls, no new secrets reads, no log delivery. Running tasks keep serving. Acceptable for dev and stage,
  not for prod.
- Prod pays for a gateway per zone to keep egress zonal.
- Cross-zone traffic from the single gateway is billed per GB; at the estimated volumes it is cents.
- Security groups, not subnets, express access: the database allows the task security groups only.
