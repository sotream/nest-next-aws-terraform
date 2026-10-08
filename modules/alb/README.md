# alb

The public application load balancer, with optional HTTPS on a custom domain.

## What it does

- An internet-facing ALB in the public subnets. Invalid header fields are dropped; deletion protection is a
  variable.
- One target group per entry in `target_groups` (IP targets for Fargate). Entries with `path_patterns`
  become listener rules; the single entry without patterns is the default route. For this project `/api/*`
  goes to the API and everything else to the web app.
- **No domain:** one HTTP listener on port 80 forwarding to the default group. The origin is
  `http://<alb dns name>`.
- **With a domain:** an ACM certificate validated through Route53, an HTTPS listener (TLS 1.3 policy
  `ELBSecurityPolicy-TLS13-1-2-2021-06`), HTTP redirecting to HTTPS and an alias record. The origin is
  `https://<domain>`. The certificate covers one name and has no SANs.

## What it does not do

- No WAF, no access logs, no Cognito or OIDC authentication. See the cost and security docs for why.
- It creates no Route53 hosted zone; pass an existing `hosted_zone_id`.

## Usage

```hcl
module "alb" {
  source            = "../alb"
  name_prefix       = "nnat-dev"
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  domain_name       = "app.example.com"
  hosted_zone_id    = "Z0000000000000000000"

  target_groups = {
    api = { port = 4000, health_path = "/api/health/ready", path_patterns = ["/api/*"], priority = 10 }
    web = { port = 3000, health_path = "/sign-in", path_patterns = [], priority = 0 }
  }
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
| public\_subnet\_ids | Public subnets for the load balancer (at least two AZs). | `list(string)` | n/a | yes |
| target\_groups | Target groups by name. Exactly one has no path\_patterns and is the default route. | <pre>map(object({<br/>    port          = number<br/>    health_path   = string<br/>    path_patterns = list(string)<br/>    priority      = number<br/>  }))</pre> | n/a | yes |
| vpc\_cidr | VPC CIDR; the load balancer may only send traffic inside it. | `string` | n/a | yes |
| vpc\_id | VPC the load balancer and target groups belong to. | `string` | n/a | yes |
| deletion\_protection | Block deletion of the load balancer. | `bool` | `false` | no |
| deregistration\_delay | Seconds the load balancer drains a target before removing it. | `number` | `30` | no |
| domain\_name | Public domain name. Empty serves plain HTTP on the load balancer DNS name. | `string` | `""` | no |
| hosted\_zone\_id | Route53 hosted zone that holds domain\_name. Required when domain\_name is set. | `string` | `""` | no |

### Outputs

| Name | Description |
| ---- | ----------- |
| alb\_arn\_suffix | Load balancer ARN suffix for CloudWatch dimensions. |
| dns\_name | DNS name of the load balancer. |
| https\_enabled | True when a domain is set and the HTTPS listener exists. |
| public\_origin | Origin users open: https://<domain> or http://<load balancer DNS name>. |
| security\_group\_id | Security group of the load balancer; target services allow ingress from it. |
| target\_group\_arn\_suffixes | Target group ARN suffixes keyed by name, for CloudWatch dimensions. |
| target\_group\_arns | Target group ARNs keyed by name. |
<!-- END_TF_DOCS -->
