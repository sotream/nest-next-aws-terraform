variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cache security group belongs to."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for the cache subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect on port 6379. The list length must be known at plan time."
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
}

variable "replicas" {
  description = "Number of replicas. Above zero enables Multi-AZ and automatic failover."
  type        = number
  default     = 0

  validation {
    condition     = var.replicas >= 0 && var.replicas <= 5
    error_message = "replicas must be between 0 and 5."
  }
}

variable "engine_version" {
  description = "Redis OSS version."
  type        = string
  default     = "7.1"
}

variable "snapshot_retention_days" {
  description = "Daily snapshot retention. Zero disables snapshots."
  type        = number
  default     = 0
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for encryption at rest. Null uses the AWS-managed key."
  type        = string
  default     = null
}

variable "auth_token" {
  description = "AUTH token. Ephemeral: it is sent to AWS and never stored in state."
  type        = string
  ephemeral   = true
}

variable "auth_token_version" {
  description = "Raise to send the token again (write-only attributes are not diffed)."
  type        = number
}
