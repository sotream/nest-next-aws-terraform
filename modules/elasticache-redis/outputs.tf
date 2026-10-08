output "primary_endpoint" {
  description = "Primary endpoint address."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = aws_elasticache_replication_group.this.port
}

output "security_group_id" {
  description = "Security group of the cache."
  value       = aws_security_group.this.id
}

output "generation_id" {
  description = "Changes whenever the cache is replaced; feeds the secrets module's redis_generation."
  value       = terraform_data.generation.id
}
