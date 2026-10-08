output "dns_name" {
  description = "DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "public_origin" {
  description = "Origin users open: https://<domain> or http://<load balancer DNS name>."
  value       = "${local.https ? "https" : "http"}://${local.public_hostname}"
}

output "https_enabled" {
  description = "True when a domain is set and the HTTPS listener exists."
  value       = local.https
}

output "security_group_id" {
  description = "Security group of the load balancer; target services allow ingress from it."
  value       = aws_security_group.this.id
}

output "target_group_arns" {
  description = "Target group ARNs keyed by name."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "alb_arn_suffix" {
  description = "Load balancer ARN suffix for CloudWatch dimensions."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffixes" {
  description = "Target group ARN suffixes keyed by name, for CloudWatch dimensions."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn_suffix }
}
