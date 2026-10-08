variable "environment" {
  description = "Environment name (dev, stage, prod). Used in resource names and decides the domain rule."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.environment))
    error_message = "environment must be 2 to 10 lowercase letters or digits, starting with a letter."
  }
}

variable "domain_name" {
  description = "Public domain name. Required for every environment except dev; empty serves dev over HTTP on the load balancer DNS name."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone that holds domain_name."
  type        = string
  default     = ""
}

variable "starter_ref" {
  description = "Commit SHA of nest-next-starter the images were built from. Informational; echoed in outputs."
  type        = string
  default     = ""
}

variable "services_image_tag" {
  description = "Image tag the api and web services run. Empty creates no services (first deployment)."
  type        = string
  default     = ""
}

variable "migrate_image_tag" {
  description = "Image tag of the migration task definition. Empty registers none."
  type        = string
  default     = ""
}

variable "credentials_version" {
  description = "Raise to rotate the database password and the Redis AUTH token."
  type        = number
  default     = 1
}

variable "jwt_version" {
  description = "Raise to rotate the JWT access secret (signs every user out)."
  type        = number
  default     = 1
}

variable "nat_mode" {
  description = "single or per_az; see the network module."
  type        = string
  default     = "single"
}

variable "api_sizing" {
  description = "API task CPU units, memory MiB and task count."
  type = object({
    cpu    = number
    memory = number
    count  = number
  })
  default = { cpu = 256, memory = 512, count = 1 }
}

variable "web_sizing" {
  description = "Web task CPU units, memory MiB and task count."
  type = object({
    cpu    = number
    memory = number
    count  = number
  })
  default = { cpu = 256, memory = 512, count = 1 }
}

variable "rds" {
  description = "Database sizing."
  type = object({
    instance_class        = string
    multi_az              = bool
    backup_retention_days = number
  })
  default = { instance_class = "db.t4g.micro", multi_az = false, backup_retention_days = 7 }
}

variable "redis" {
  description = "Cache sizing."
  type = object({
    node_type               = string
    replicas                = number
    snapshot_retention_days = number
  })
  default = { node_type = "cache.t4g.micro", replicas = 0, snapshot_retention_days = 0 }
}

variable "deletion_protection" {
  description = "Protect the database and the load balancer from deletion (and take a final database snapshot)."
  type        = bool
  default     = false
}

variable "final_snapshot_on_destroy" {
  description = "Take a final database snapshot when the database is destroyed. Keep it true wherever the data matters; it is separate from deletion_protection, which is switched off to destroy."
  type        = bool
  default     = true
}

variable "api_health_path" {
  description = "Health path of the API target group. /api/health/ready (database and Redis) takes an unready task out of the load balancer, but ECS also replaces tasks the load balancer reports unhealthy, so a database or Redis outage makes ECS restart every API task. /api/health/live avoids that."
  type        = string
  default     = "/api/health/ready"

  validation {
    condition     = contains(["/api/health/ready", "/api/health/live"], var.api_health_path)
    error_message = "api_health_path must be /api/health/ready or /api/health/live."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 14
}

variable "alarm_email" {
  description = "Email address for alarms. Empty creates no subscription."
  type        = string
  default     = ""
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every role in the stack. Null attaches none."
  type        = string
  default     = null
}
