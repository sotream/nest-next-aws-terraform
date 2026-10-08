variable "name_prefix" {
  description = "Prefix for every resource name, for example nnat-dev."
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block. Subnets are carved out of it with /20 masks when this is a /16."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "nat_mode" {
  description = "single: one NAT gateway shared by all AZs (cheaper, one AZ is a single point of failure for egress). per_az: one per AZ."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_mode)
    error_message = "nat_mode must be \"single\" or \"per_az\"."
  }
}

variable "flow_log_retention_days" {
  description = "Retention of the VPC flow log group."
  type        = number
  default     = 14
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary attached to every role this module creates. Null attaches none."
  type        = string
  default     = null
}
