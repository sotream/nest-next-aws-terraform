variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "eu-central-1"
}

variable "name_prefix" {
  description = "Prefix for the CI roles and policies. The deploy role may only manage IAM roles under the path /nnat/."
  type        = string
  default     = "nnat"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as owner/name."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "state_bucket_name" {
  description = "Globally unique name of the S3 bucket that holds the Terraform state."
  type        = string
}

variable "environments" {
  description = "Environments that get a deploy role, matching the GitHub Environment names."
  type        = set(string)
  default     = ["dev", "stage", "prod"]
}
