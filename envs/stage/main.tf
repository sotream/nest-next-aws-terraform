provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "nest-next-aws-terraform"
      Environment = "stage"
      ManagedBy   = "terraform"
    }
  }
}

# Everything lives in modules/app-stack; this root only picks the environment's values.
module "app" {
  source = "../../modules/app-stack"

  environment               = "stage"
  domain_name               = var.domain_name
  hosted_zone_id            = var.hosted_zone_id
  starter_ref               = var.starter_ref
  services_image_tag        = var.services_image_tag
  migrate_image_tag         = var.migrate_image_tag
  credentials_version       = var.credentials_version
  jwt_version               = var.jwt_version
  nat_mode                  = var.nat_mode
  api_sizing                = var.api_sizing
  web_sizing                = var.web_sizing
  rds                       = var.rds
  redis                     = var.redis
  deletion_protection       = var.deletion_protection
  api_health_path           = var.api_health_path
  log_retention_days        = var.log_retention_days
  final_snapshot_on_destroy = var.final_snapshot_on_destroy
  alarm_email               = var.alarm_email

  permissions_boundary_arn = var.permissions_boundary_arn
}
