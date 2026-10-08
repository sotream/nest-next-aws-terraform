# Cost estimate

A rough monthly estimate per environment, so nobody is surprised by a bill. **These are estimates, not
quotes.** They use on-demand list prices for `eu-central-1` as understood at the time of writing
(October 2026), were not looked up in the AWS Pricing Calculator for this repository, and will drift. Check
the [AWS Pricing Calculator](https://calculator.aws/) before you rely on them.

## Assumptions

- 730 hours a month, USD, no free tier, no savings plans, no reserved instances.
- Fargate Linux x86: about 0.0466 USD per vCPU-hour and 0.0051 USD per GB-hour.
- Low traffic: about 20 GB a month through the NAT gateway, one load balancer capacity unit on average,
  under 5 GB of logs, 20 GB of database storage.
- Two availability zones. A NAT gateway is about 0.052 USD per hour plus 0.052 USD per GB processed.
- An Application Load Balancer is about 0.024 USD per hour plus capacity units.
- No WAF, no ALB access logs, no data transfer to the internet beyond a few GB.
- The Route 53 hosted zone (about 0.50 USD) is not created by this repository and not counted.

## Per environment, per month

| Item                                        | dev                              | stage                  | prod                            |
| ------------------------------------------- | -------------------------------- | ---------------------- | ------------------------------- |
| NAT gateways                                | 1: 38                            | 1: 38                  | 2: 76                           |
| NAT data processing                         | 1                                | 1                      | 2                               |
| Application Load Balancer                   | 23                               | 23                     | 25                              |
| Fargate tasks (api and web)                 | 2 x 0.25 vCPU, 0.5 GB: 21        | 2 x 0.5 vCPU, 1 GB: 41 | 4 x 0.5 vCPU, 1 GB: 83          |
| RDS PostgreSQL and storage                  | `t4g.micro` single-AZ, 20 GB: 17 | same: 17               | `t4g.small` Multi-AZ, 20 GB: 61 |
| ElastiCache Redis                           | `t4g.micro`, 1 node: 12          | same: 12               | `t4g.small`, 2 nodes: 50        |
| Secrets Manager (3 secrets)                 | 1                                | 1                      | 1                               |
| KMS keys (shared and database)              | 2                                | 2                      | 2                               |
| CloudWatch logs, alarms, Container Insights | 5                                | 6                      | 12                              |
| ECR, flow logs, other                       | 2                                | 2                      | 4                               |
| **Approximate total**                       | **about 120**                    | **about 145**          | **about 315**                   |

Shared across all environments: the state bucket and its KMS key (about 1 to 2 USD).

What moves the numbers most: the NAT gateway count, Multi-AZ, and the number and size of Fargate tasks.
Data transfer out and a busy database can add more than anything above.

## Cheapest way to try it

- Use **dev only**, without a domain (HTTP on the ALB name) or with one.
- Keep `nat_mode = "single"`, one task per service, `db.t4g.micro` single-AZ.
- Destroy it when you are finished (below): about 4 USD a day while it exists.
- A stopped environment still costs money for RDS, ElastiCache, the NAT gateway and the load balancer. There
  is no cheap "pause", only destroy and recreate.

## How to destroy

Order matters, because some resources refuse to be deleted. The full procedure with commands is in the
[operations runbook](operations.md#destroy-an-environment). In short:

1. Prod only: set `deletion_protection = false` and apply.
2. Empty the two ECR repositories.
3. `terraform -chdir=envs/<name> destroy`.
4. Force-delete the three secrets if you want to recreate the environment within 7 days.
5. Repeat for every environment, then retire `bootstrap/` last (empty and unprotect the state bucket).

What keeps costing money if you skip a step: ECR images (cents), KMS keys in their 30-day deletion window (1
USD each), the state bucket and, if you forget an environment, everything in the table above.
