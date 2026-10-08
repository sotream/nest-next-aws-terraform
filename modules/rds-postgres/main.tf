locals {
  major_version = split(".", var.engine_version)[0]
}

data "aws_caller_identity" "current" {}

# The default key policy, written out: the account (and IAM policies within it) administers the key.
data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_111:In a key policy "*" means this key only, and the account root statement is the AWS default
  #checkov:skip=CKV_AWS_356:In a key policy "*" means this key only
  #checkov:skip=CKV_AWS_109:Account-wide key administration is the AWS default; access is then granted through IAM
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "this" {
  description         = "${var.name_prefix} database encryption"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-rds"
  description = "PostgreSQL access from the application tasks"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name_prefix}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from application tasks"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-postgres"
  subnet_ids = var.subnet_ids
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-postgres${local.major_version}"
  family = "postgres${local.major_version}"

  # Connections must use TLS. The starter reaches it through ?sslmode= in DATABASE_URL, which pg reads from
  # the connection string TypeORM hands over. See ADR 0008.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_118:Enhanced monitoring needs an extra IAM role and costs money; CloudWatch metrics and alarms cover the basics
  #checkov:skip=CKV_AWS_353:Performance Insights is not needed for a demo workload
  #checkov:skip=CKV_AWS_354:Performance Insights is not enabled, so there is no key to encrypt
  #checkov:skip=CKV2_AWS_30:Query logging is not required here; the postgresql log export is enabled
  #checkov:skip=CKV_AWS_293:Deletion protection is the deletion_protection variable; prod sets it, dev and stage must be destroyable
  #checkov:skip=CKV_AWS_157:Multi-AZ is a per-environment variable; dev and stage run single-AZ to save cost
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username
  # Write-only: never stored in state. Rotated by raising password_version.
  password_wo         = var.password
  password_wo_version = var.password_version

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.this.arn

  multi_az               = var.multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  backup_retention_period    = var.backup_retention_days
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = !var.final_snapshot
  final_snapshot_identifier  = var.final_snapshot ? "${var.name_prefix}-postgres-final-${formatdate("YYYYMMDDhhmmss", timestamp())}" : null

  # The identifier is chosen when the instance is created (a fixed name would fail on a second destroy) and
  # must not change on later plans, when timestamp() yields a new value.
  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
}
