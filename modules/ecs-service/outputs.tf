output "security_group_id" {
  description = "Security group of the tasks; the database and cache allow ingress from it."
  value       = aws_security_group.this.id
}

output "task_definition_arn" {
  description = "Task definition ARN, or null when the module is disabled."
  value       = one(aws_ecs_task_definition.this[*].arn)
}

output "service_name" {
  description = "ECS service name, or null when no service is created."
  value       = one(aws_ecs_service.this[*].name)
}
