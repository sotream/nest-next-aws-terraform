variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "credentials_version" {
  description = "Bump to rotate the database password and the Redis token. Write-only attributes are only sent when their version changes."
  type        = number
  default     = 1

  validation {
    condition     = var.credentials_version >= 1
    error_message = "credentials_version must be 1 or higher."
  }
}

variable "jwt_version" {
  description = "Bump to rotate the JWT access secret. Rotating it signs every user out."
  type        = number
  default     = 1

  validation {
    condition     = var.jwt_version >= 1
    error_message = "jwt_version must be 1 or higher."
  }
}

variable "db_username" {
  description = "Database user placed in the DATABASE_URL secret."
  type        = string
  default     = "app"
}

variable "db_name" {
  description = "Database name placed in the DATABASE_URL secret."
  type        = string
  default     = "app"
}

variable "db_host" {
  description = "Database endpoint address."
  type        = string
}

variable "db_generation" {
  description = "Value that changes whenever the database instance is replaced (for example its resource id). A replacement under the same name keeps the same host, so the host cannot signal it."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
  default     = 5432
}

variable "redis_host" {
  description = "Redis primary endpoint address."
  type        = string
}

variable "redis_generation" {
  description = "Value that changes whenever the cache is replaced (see the elasticache-redis module output generation_id)."
  type        = string
}

variable "redis_port" {
  description = "Redis port."
  type        = number
  default     = 6379
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for the secrets. Null uses the AWS-managed Secrets Manager key."
  type        = string
  default     = null
}

variable "db_ssl_mode" {
  description = "sslmode added to DATABASE_URL. no-verify encrypts without checking the server certificate (Node does not trust the RDS CA by default); verify-full needs the RDS CA bundle in the image."
  type        = string
  default     = "no-verify"

  validation {
    condition     = contains(["no-verify", "verify-full"], var.db_ssl_mode)
    error_message = "db_ssl_mode must be no-verify or verify-full."
  }
}
