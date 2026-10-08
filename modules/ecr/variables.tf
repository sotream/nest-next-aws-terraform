variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "repositories" {
  description = "Repository short names. Each becomes <name_prefix>/<name>."
  type        = set(string)
  default     = ["api", "web"]
}

variable "keep_images" {
  description = "Number of most recent images kept per repository."
  type        = number
  default     = 10

  validation {
    condition     = var.keep_images >= 1
    error_message = "keep_images must be at least 1."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for image encryption. Null uses the AWS-managed ECR key."
  type        = string
  default     = null
}
