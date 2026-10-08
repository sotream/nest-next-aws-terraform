output "db_password" {
  description = "Ephemeral database password for the rds-postgres module."
  value       = ephemeral.random_password.db.result
  ephemeral   = true
}

output "redis_auth_token" {
  description = "Ephemeral Redis AUTH token for the elasticache-redis module."
  value       = ephemeral.random_password.redis.result
  ephemeral   = true
}

output "db_password_version" {
  description = "Version to pass as password_wo_version: credentials_version."
  value       = var.credentials_version
}

output "redis_token_version" {
  description = "Version to pass as auth_token_wo_version: credentials_version."
  value       = var.credentials_version
}

output "database_url_secret_version" {
  description = "Version of the DATABASE_URL secret: credentials_version plus a hash of db_generation."
  value       = local.db_url_version
}

output "redis_url_secret_version" {
  description = "Version of the REDIS_URL secret: credentials_version plus a hash of redis_generation."
  value       = local.redis_url_version
}

output "secret_arns" {
  description = "Secret ARNs keyed by the container environment variable they feed."
  value = {
    database_url      = aws_secretsmanager_secret.this["database-url"].arn
    redis_url         = aws_secretsmanager_secret.this["redis-url"].arn
    jwt_access_secret = aws_secretsmanager_secret.this["jwt-access-secret"].arn
  }
}

output "database_url_query" {
  description = "Query string appended to DATABASE_URL (not secret); exposed so tests can check it."
  value       = local.db_query
}
