output "execution_role_arn" {
  description = "ECS task execution role ARN."
  value       = aws_iam_role.execution.arn
}

output "task_role_arns" {
  description = "Task role ARNs keyed by service."
  value       = { for k, r in aws_iam_role.task : k => r.arn }
}
