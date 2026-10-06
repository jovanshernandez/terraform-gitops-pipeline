variable "name" {
  description = "Service name used as the prefix for every resource name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name))
    error_message = "name must be 3-32 characters of lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment. Only dev and prod have a pipeline and state backend."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be \"dev\" or \"prod\"."
  }
}

variable "vpc_id" {
  description = "VPC that owns the security group. The network is managed by a separate stack."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]{8,17}$", var.vpc_id))
    error_message = "vpc_id must look like vpc-0123456789abcdef0."
  }
}

variable "subnet_ids" {
  description = "Private subnets to spread instances across, in order. Instances get no public IP."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0 && alltrue([for id in var.subnet_ids : can(regex("^subnet-[0-9a-f]{8,17}$", id))])
    error_message = "subnet_ids must contain at least one subnet ID like subnet-0123456789abcdef0."
  }
}

variable "ami_id" {
  description = "AMI for the instances. Pin it in the environment root so an AMI bump is a reviewed change."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must look like ami-0123456789abcdef0."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Restricted to current-generation burstable and general purpose families."
  type        = string
  default     = "t4g.micro"

  validation {
    condition     = can(regex("^(t3|t3a|t4g|m6i|m7i|m7g)\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must be in the t3, t3a, t4g, m6i, m7i or m7g families."
  }
}

variable "instance_count" {
  description = "Number of instances. Capped so a typo cannot launch a fleet."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 6 && floor(var.instance_count) == var.instance_count
    error_message = "instance_count must be a whole number from 1 to 6."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 200
    error_message = "root_volume_size must be between 8 and 200 GiB."
  }
}

variable "kms_key_id" {
  description = "Optional customer managed KMS key ARN for the root volume. Null uses the account's default EBS key."
  type        = string
  default     = null
}

variable "app_port" {
  description = "TCP port the service listens on."
  type        = number
  default     = 8080

  validation {
    condition     = var.app_port >= 1024 && var.app_port <= 65535
    error_message = "app_port must be an unprivileged port (1024-65535)."
  }
}

variable "ingress_cidr_blocks" {
  description = "Private CIDR ranges allowed to reach app_port. Public ranges are rejected."
  type        = list(string)

  validation {
    condition     = length(var.ingress_cidr_blocks) > 0 && alltrue([for cidr in var.ingress_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "ingress_cidr_blocks must contain at least one valid CIDR range."
  }

  validation {
    condition = alltrue([
      for cidr in var.ingress_cidr_blocks : can(regex(
        "^(10\\.\\d+\\.\\d+\\.\\d+/([89]|[12]\\d|3[0-2])|172\\.(1[6-9]|2\\d|3[01])\\.\\d+\\.\\d+/(1[2-9]|2\\d|3[0-2])|192\\.168\\.\\d+\\.\\d+/(1[6-9]|2\\d|3[0-2]))$",
        cidr
      ))
    ])
    error_message = "ingress_cidr_blocks must be RFC 1918 private ranges; this service is not internet facing."
  }
}

variable "tags" {
  description = "Extra tags for every resource in the module (the provider adds the standard set)."
  type        = map(string)
  default     = {}
}
