output "address" {
  description = "Database endpoint address."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Database port."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "Security group of the database."
  value       = aws_security_group.this.id
}

output "instance_id" {
  description = "DB instance identifier, used by alarms."
  value       = aws_db_instance.this.identifier
}

output "kms_key_arn" {
  description = "KMS key that encrypts the database."
  value       = aws_kms_key.this.arn
}

output "instance_resource_id" {
  description = "Immutable RDS resource id; changes whenever the instance is replaced. Feeds the secrets module's db_generation."
  value       = aws_db_instance.this.resource_id
}
