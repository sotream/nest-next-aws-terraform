output "app_env" {
  description = "APP_ENV the starter runs with: prod when a domain is set, dev otherwise."
  value       = local.app_env
}

output "public_origin" {
  description = "Origin users open; also WEB_ORIGIN and the NEXT_PUBLIC_API_URL the web image is built with."
  value       = module.alb.public_origin
}

output "alb_dns_name" {
  description = "DNS name of the load balancer."
  value       = module.alb.dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by api and web."
  value       = module.ecr.repository_urls
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "migrate_task_definition_arn" {
  description = "Migration task definition ARN, or null until migrate_image_tag is set."
  value       = module.migrate.task_definition_arn
}

output "private_subnet_ids" {
  description = "Private subnet IDs, for run-task network configuration."
  value       = module.network.private_subnet_ids
}

output "migrate_security_group_id" {
  description = "Security group of the migration task."
  value       = module.migrate.security_group_id
}

output "services_image_tag" {
  description = "Image tag the services currently run."
  value       = var.services_image_tag
}

output "starter_ref" {
  description = "Starter commit the running images were built from, as last recorded."
  value       = var.starter_ref
}
