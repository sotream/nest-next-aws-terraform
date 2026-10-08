variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database security group belongs to."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (at least two AZs)."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on port 5432. The list length must be known at plan time."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL version. The major version selects the parameter group family."
  type        = string
  default     = "17"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "multi_az" {
  description = "Run a standby in a second AZ."
  type        = bool
  default     = false
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 100
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "final_snapshot" {
  description = "Take a final snapshot when the instance is destroyed. Independent of deletion_protection, which is switched off to destroy."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Block deletion of the instance."
  type        = bool
  default     = false
}

variable "username" {
  description = "Master username."
  type        = string
  default     = "app"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "app"
}

variable "password" {
  description = "Master password. Ephemeral: it is sent to AWS and never stored in state."
  type        = string
  ephemeral   = true
}

variable "password_version" {
  description = "Raise to send the password again (write-only attributes are not diffed)."
  type        = number
}
