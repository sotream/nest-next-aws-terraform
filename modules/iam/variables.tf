variable "name_prefix" {
  description = "Prefix for every role name, for example nnat-dev."
  type        = string
}

variable "services" {
  description = "Services that get a task role."
  type        = set(string)
}

variable "secret_arns" {
  description = "Secrets Manager secret ARNs the execution role may read."
  type        = list(string)
}

variable "repository_arns" {
  description = "ECR repository ARNs the execution role may pull from."
  type        = list(string)
}

variable "log_group_arns" {
  description = "CloudWatch log group ARNs the execution role may write to."
  type        = list(string)
}

variable "kms_key_arns" {
  description = "KMS keys that encrypt the secrets. Leave empty when the AWS-managed key is used."
  type        = list(string)
  default     = []
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every role this module creates. Null attaches none."
  type        = string
  default     = null
}
