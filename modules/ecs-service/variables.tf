variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "name" {
  description = "Short service name: api, web or migrate."
  type        = string
}

variable "enabled" {
  description = "Plan the task definition and service. False before the first image exists."
  type        = bool
}

variable "create_service" {
  description = "Create an ECS service. False for one-off tasks such as migrations (task definition only)."
  type        = bool
  default     = true
}

variable "cluster_arn" {
  description = "ECS cluster ARN."
  type        = string
}

variable "image" {
  description = "Full image URI including the tag."
  type        = string
}

variable "cpu" {
  description = "Task CPU units (256, 512, 1024, ...)."
  type        = number
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
}

variable "port" {
  description = "Container port. Zero for tasks that serve nothing."
  type        = number
}

variable "command" {
  description = "Container command override. Empty keeps the image default."
  type        = list(string)
  default     = []
}

variable "environment" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container secrets: environment variable name to Secrets Manager ARN."
  type        = map(string)
  default     = {}
}

variable "health_command" {
  description = "Container health check command without the CMD prefix. Empty disables it."
  type        = list(string)
  default     = []
}

variable "desired_count" {
  description = "Number of running tasks."
  type        = number
  default     = 1
}

variable "execution_role_arn" {
  description = "Task execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "Task role ARN."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC of the tasks."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group the container writes to."
  type        = string
}

variable "register_with_alb" {
  description = "Attach the service to a load balancer target group. A plain bool because the target group ARN is unknown at plan time."
  type        = bool
  default     = false
}

variable "target_group_arn" {
  description = "Target group ARN. Used when register_with_alb is true."
  type        = string
  default     = null
}

variable "alb_security_group_id" {
  description = "Load balancer security group allowed to reach the task port. Used when register_with_alb is true."
  type        = string
  default     = null
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores failing load balancer health checks after a task starts."
  type        = number
  default     = 60
}
