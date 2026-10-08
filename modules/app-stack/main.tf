data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix = "nnat-${var.environment}"
  has_domain  = var.domain_name != ""
  # The starter refuses to start with APP_ENV=prod over http (Secure cookie, https WEB_ORIGIN), so an
  # environment without a domain has to run as dev. See docs/guides/environments.md.
  app_env = local.has_domain ? "prod" : "dev"

  services_enabled = var.services_image_tag != ""
  migrate_enabled  = var.migrate_image_tag != ""

  # Same environment and secrets for the API and the migration task: the starter validates its whole
  # environment before running any command.
  api_environment = {
    APP_ENV       = local.app_env
    PORT          = "4000"
    WEB_ORIGIN    = module.alb.public_origin
    LOG_LEVEL     = "info"
    KAFKA_ENABLED = "false"
  }
  api_secrets = {
    DATABASE_URL      = module.secrets.secret_arns["database_url"]
    REDIS_URL         = module.secrets.secret_arns["redis_url"]
    JWT_ACCESS_SECRET = module.secrets.secret_arns["jwt_access_secret"]
  }

  log_group_names = ["api", "web", "migrate"]
}

resource "terraform_data" "guard" {
  lifecycle {
    precondition {
      condition     = var.environment == "dev" || local.has_domain
      error_message = "stage and prod need domain_name: the starter's APP_ENV=prod requires an https WEB_ORIGIN."
    }
  }
}

# One customer-managed key for logs, alarm notifications, secrets, images and the cache. The database has
# its own key inside the rds-postgres module.
resource "aws_kms_key" "shared" {
  description         = "${local.name_prefix} shared encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*" # in a key policy "*" means this key
      },
      {
        Sid       = "CloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.current.region}.amazonaws.com" }
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/${local.name_prefix}/*"
          }
        }
      },
      {
        Sid       = "CloudWatchAlarmsToSns"
        Effect    = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource  = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "shared" {
  name          = "alias/${local.name_prefix}-shared"
  target_key_id = aws_kms_key.shared.key_id
}

module "network" {
  source = "../network"

  name_prefix              = local.name_prefix
  nat_mode                 = var.nat_mode
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "ecr" {
  source = "../ecr"

  name_prefix = local.name_prefix
  kms_key_arn = aws_kms_key.shared.arn
}

module "alb" {
  source = "../alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr
  public_subnet_ids   = module.network.public_subnet_ids
  domain_name         = var.domain_name
  hosted_zone_id      = var.hosted_zone_id
  deletion_protection = var.deletion_protection

  target_groups = {
    api = { port = 4000, health_path = var.api_health_path, path_patterns = ["/api/*"], priority = 10 }
    web = { port = 3000, health_path = "/sign-in", path_patterns = [], priority = 0 }
  }
}

module "secrets" {
  source = "../secrets"

  name_prefix         = local.name_prefix
  credentials_version = var.credentials_version
  jwt_version         = var.jwt_version
  db_host             = module.rds.address
  db_generation       = module.rds.instance_resource_id
  db_port             = module.rds.port
  redis_host          = module.redis.primary_endpoint
  redis_generation    = module.redis.generation_id
  redis_port          = module.redis.port
  kms_key_arn         = aws_kms_key.shared.arn
}

module "rds" {
  source = "../rds-postgres"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.api.security_group_id, module.migrate.security_group_id]
  instance_class             = var.rds.instance_class
  multi_az                   = var.rds.multi_az
  backup_retention_days      = var.rds.backup_retention_days
  deletion_protection        = var.deletion_protection
  final_snapshot             = var.final_snapshot_on_destroy
  password                   = module.secrets.db_password
  password_version           = module.secrets.db_password_version
}

module "redis" {
  source = "../elasticache-redis"

  name_prefix                = local.name_prefix
  vpc_id                     = module.network.vpc_id
  subnet_ids                 = module.network.private_subnet_ids
  allowed_security_group_ids = [module.api.security_group_id, module.migrate.security_group_id]
  node_type                  = var.redis.node_type
  replicas                   = var.redis.replicas
  snapshot_retention_days    = var.redis.snapshot_retention_days
  kms_key_arn                = aws_kms_key.shared.arn
  auth_token                 = module.secrets.redis_auth_token
  auth_token_version         = module.secrets.redis_token_version
}

module "observability" {
  source = "../observability-basics"

  name_prefix               = local.name_prefix
  log_groups                = local.log_group_names
  alarmed_services          = ["api", "web"]
  retention_days            = var.log_retention_days
  cluster_name              = local.name_prefix
  alb_arn_suffix            = module.alb.alb_arn_suffix
  target_group_arn_suffixes = module.alb.target_group_arn_suffixes
  rds_instance_id           = module.rds.instance_id
  kms_key_arn               = aws_kms_key.shared.arn
  alarm_email               = var.alarm_email
}

module "iam" {
  source = "../iam"

  name_prefix     = local.name_prefix
  services        = ["api", "web"]
  secret_arns     = values(module.secrets.secret_arns)
  repository_arns = values(module.ecr.repository_arns)
  log_group_arns  = module.observability.log_group_arns
  kms_key_arns    = [aws_kms_key.shared.arn]

  permissions_boundary_arn = var.permissions_boundary_arn
}

resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "api" {
  source = "../ecs-service"

  name_prefix           = local.name_prefix
  name                  = "api"
  enabled               = local.services_enabled
  cluster_arn           = aws_ecs_cluster.this.arn
  image                 = "${module.ecr.repository_urls["api"]}:${var.services_image_tag}"
  cpu                   = var.api_sizing.cpu
  memory                = var.api_sizing.memory
  port                  = 4000
  desired_count         = var.api_sizing.count
  environment           = local.api_environment
  secrets               = local.api_secrets
  health_command        = ["node", "-e", "fetch('http://127.0.0.1:4000/api/health/live').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arns["api"]
  subnet_ids            = module.network.private_subnet_ids
  vpc_id                = module.network.vpc_id
  log_group_name        = module.observability.log_group_names["api"]
  register_with_alb     = true
  target_group_arn      = module.alb.target_group_arns["api"]
  alb_security_group_id = module.alb.security_group_id
}

module "web" {
  source = "../ecs-service"

  name_prefix           = local.name_prefix
  name                  = "web"
  enabled               = local.services_enabled
  cluster_arn           = aws_ecs_cluster.this.arn
  image                 = "${module.ecr.repository_urls["web"]}:${var.services_image_tag}"
  cpu                   = var.web_sizing.cpu
  memory                = var.web_sizing.memory
  port                  = 3000
  desired_count         = var.web_sizing.count
  health_command        = ["node", "-e", "fetch('http://127.0.0.1:3000/sign-in').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
  execution_role_arn    = module.iam.execution_role_arn
  task_role_arn         = module.iam.task_role_arns["web"]
  subnet_ids            = module.network.private_subnet_ids
  vpc_id                = module.network.vpc_id
  log_group_name        = module.observability.log_group_names["web"]
  register_with_alb     = true
  target_group_arn      = module.alb.target_group_arns["web"]
  alb_security_group_id = module.alb.security_group_id
}

# A task definition only: the deploy workflow starts it once with `aws ecs run-task` before the services roll.
module "migrate" {
  source = "../ecs-service"

  name_prefix        = local.name_prefix
  name               = "migrate"
  enabled            = local.migrate_enabled
  create_service     = false
  cluster_arn        = aws_ecs_cluster.this.arn
  image              = "${module.ecr.repository_urls["api"]}:${var.migrate_image_tag}"
  cpu                = 256
  memory             = 512
  port               = 0
  command            = ["node", "node_modules/typeorm/cli.js", "migration:run", "-d", "dist/infrastructure/database/data-source.js"]
  environment        = local.api_environment
  secrets            = local.api_secrets
  execution_role_arn = module.iam.execution_role_arn
  task_role_arn      = module.iam.task_role_arns["api"]
  subnet_ids         = module.network.private_subnet_ids
  vpc_id             = module.network.vpc_id
  log_group_name     = module.observability.log_group_names["migrate"]
}
