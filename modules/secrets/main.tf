# Ephemeral values exist only during a run. They are never stored in state or plan files.
ephemeral "random_password" "db" {
  length  = 40
  special = false # the value is embedded in a URL
}

ephemeral "random_password" "redis" {
  length  = 40
  special = false # ElastiCache AUTH tokens allow a restricted character set
}

ephemeral "random_password" "jwt" {
  length  = 64
  special = false
}

locals {
  # pg reads this from the connection string TypeORM passes through, so the starter needs no ssl option.
  db_query = "sslmode=${var.db_ssl_mode}"

  # A write-only value is only re-sent when its version changes, but the URL secrets embed a password that
  # is regenerated on every run. A replaced database or cache is created with a new password in the same
  # apply, so its URL secret must be rewritten then. The host cannot signal that: an instance replaced
  # under the same identifier keeps its endpoint. The generation does change on replacement. The versions
  # given to the database and cache must not include it: it is an output of the resource that consumes them.
  db_url_version    = var.credentials_version + parseint(substr(md5(var.db_generation), 0, 6), 16)
  redis_url_version = var.credentials_version + parseint(substr(md5(var.redis_generation), 0, 6), 16)
}

resource "aws_secretsmanager_secret" "this" {
  #checkov:skip=CKV2_AWS_57:Automatic rotation needs a Lambda; rotation is a manual version bump, see ADR 0003
  for_each = toset(["database-url", "redis-url", "jwt-access-secret"])

  name                    = "${var.name_prefix}/${each.key}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id                = aws_secretsmanager_secret.this["database-url"].id
  secret_string_wo         = "postgres://${var.db_username}:${ephemeral.random_password.db.result}@${var.db_host}:${var.db_port}/${var.db_name}?${local.db_query}"
  secret_string_wo_version = local.db_url_version
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id                = aws_secretsmanager_secret.this["redis-url"].id
  secret_string_wo         = "rediss://:${ephemeral.random_password.redis.result}@${var.redis_host}:${var.redis_port}"
  secret_string_wo_version = local.redis_url_version
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id                = aws_secretsmanager_secret.this["jwt-access-secret"].id
  secret_string_wo         = ephemeral.random_password.jwt.result
  secret_string_wo_version = var.jwt_version
}
