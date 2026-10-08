variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the load balancer and target groups belong to."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR; the load balancer may only send traffic inside it."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the load balancer (at least two AZs)."
  type        = list(string)
}

variable "target_groups" {
  description = "Target groups by name. Exactly one has no path_patterns and is the default route."
  type = map(object({
    port          = number
    health_path   = string
    path_patterns = list(string)
    priority      = number
  }))

  validation {
    condition     = length([for tg in var.target_groups : tg if length(tg.path_patterns) == 0]) == 1
    error_message = "Exactly one target group must have empty path_patterns (the default route)."
  }
}

variable "domain_name" {
  description = "Public domain name. Empty serves plain HTTP on the load balancer DNS name."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone that holds domain_name. Required when domain_name is set."
  type        = string
  default     = ""

  validation {
    condition     = var.domain_name == "" || var.hosted_zone_id != ""
    error_message = "hosted_zone_id is required when domain_name is set."
  }
}

variable "deregistration_delay" {
  description = "Seconds the load balancer drains a target before removing it."
  type        = number
  default     = 30
}

variable "deletion_protection" {
  description = "Block deletion of the load balancer."
  type        = bool
  default     = false
}
