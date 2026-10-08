resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-redis"
  description = "Redis access from the application tasks"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-redis" }
}

resource "aws_vpc_security_group_ingress_rule" "redis" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  description                  = "Redis from application tasks"
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.subnet_ids
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name_prefix}-redis7"
  family = "redis7"

  # The starter stores rate-limit counters in Redis; evicting them would silently reset the limits.
  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_elasticache_replication_group" "this" {
  #checkov:skip=CKV_AWS_31:The token is sent through auth_token_wo, which the check does not recognise
  #checkov:skip=CKV2_AWS_50:Multi-AZ failover is the replicas variable; dev and stage run a single node to save cost
  replication_group_id = "${var.name_prefix}-redis"
  description          = "${var.name_prefix} rate-limit counters"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.this.name

  num_cache_clusters         = 1 + var.replicas
  automatic_failover_enabled = var.replicas > 0
  multi_az_enabled           = var.replicas > 0

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  # Write-only: never stored in state. Rotated by raising auth_token_version.
  auth_token_wo         = var.auth_token
  auth_token_wo_version = var.auth_token_version

  snapshot_retention_limit   = var.snapshot_retention_days
  auto_minor_version_upgrade = true

  # Without this a changed AUTH token waits for the maintenance window while the URL secret already holds
  # the new one. With the default ROTATE strategy the previous token stays valid until it is replaced.
  apply_immediately = true
}

# Changes id whenever the replication group is replaced. The endpoint of a replacement can be identical, so
# the secrets module uses this to know that the cache has a new AUTH token.
resource "terraform_data" "generation" {
  lifecycle {
    replace_triggered_by = [aws_elasticache_replication_group.this]
  }
}
