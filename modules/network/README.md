# network

VPC with public and private subnets across 2 or 3 availability zones and a configurable NAT layout.

## What it does

- One VPC, one public and one private subnet per AZ, an internet gateway and per-AZ private route tables.
- `nat_mode = "single"` shares one NAT gateway; `"per_az"` creates one per AZ. The trade-off and the cost
  are in [ADR 0002](../../docs/adr/0002-network-and-nat.md).
- A free S3 gateway endpoint so ECR layer downloads skip the NAT.
- VPC flow logs to CloudWatch; the default security group carries no rules.

## What it does not do

- No interface endpoints (ECR, Secrets Manager, Logs): they cost more than the NAT at this traffic level.
- No IPv6, no VPN, no peering.

## Usage

```hcl
module "network" {
  source      = "../network"
  name_prefix = "nnat-dev"
  nat_mode    = "single"
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
| name\_prefix | Prefix for every resource name, for example nnat-dev. | `string` | n/a | yes |
| az\_count | Number of availability zones to use. | `number` | `2` | no |
| cidr | VPC CIDR block. Subnets are carved out of it with /20 masks when this is a /16. | `string` | `"10.0.0.0/16"` | no |
| flow\_log\_retention\_days | Retention of the VPC flow log group. | `number` | `14` | no |
| nat\_mode | single: one NAT gateway shared by all AZs (cheaper, one AZ is a single point of failure for egress). per\_az: one per AZ. | `string` | `"single"` | no |
| permissions\_boundary\_arn | Permissions boundary attached to every role this module creates. Null attaches none. | `string` | `null` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| nat\_gateway\_count | Number of NAT gateways created. |
| private\_subnet\_ids | Private subnet IDs, one per AZ. |
| public\_subnet\_ids | Public subnet IDs, one per AZ. |
| vpc\_cidr | VPC CIDR block. |
| vpc\_id | VPC ID. |
<!-- END_TF_DOCS -->
