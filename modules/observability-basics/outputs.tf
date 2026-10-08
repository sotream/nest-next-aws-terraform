output "log_group_names" {
  description = "Log group names keyed by short name."
  value       = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}

output "log_group_arns" {
  description = "Log group ARNs."
  value       = [for g in aws_cloudwatch_log_group.this : g.arn]
}

output "sns_topic_arn" {
  description = "Alarm topic ARN."
  value       = aws_sns_topic.alarms.arn
}
