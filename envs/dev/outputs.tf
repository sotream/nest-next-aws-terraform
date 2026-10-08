output "app_env" {
  value = module.app.app_env
}

output "public_origin" {
  value = module.app.public_origin
}

output "alb_dns_name" {
  value = module.app.alb_dns_name
}

output "ecr_repository_urls" {
  value = module.app.ecr_repository_urls
}

output "cluster_name" {
  value = module.app.cluster_name
}

output "migrate_task_definition_arn" {
  value = module.app.migrate_task_definition_arn
}

output "private_subnet_ids" {
  value = module.app.private_subnet_ids
}

output "migrate_security_group_id" {
  value = module.app.migrate_security_group_id
}

output "services_image_tag" {
  value = module.app.services_image_tag
}

output "starter_ref" {
  value = module.app.starter_ref
}
