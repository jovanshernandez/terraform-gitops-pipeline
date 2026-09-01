variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "project" {
  description = "Project name used for tags and resource names."
  type        = string
  default     = "gitops-workflow"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "instance_count" {
  description = "Number of EC2 instances to create."
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 3
    error_message = "instance_count must be between 1 and 3 for this demo."
  }
}

variable "key_name" {
  description = "EC2 key pair name."
  type        = string
  default     = "baxter-devops"
}

variable "instance_type" {
  description = "AWS instance type."
  type        = string
  default     = "t2.micro"
}

variable "ami" {
  description = "Base AMI used by the EC2 instances."
  type        = string
  default     = "ami-08d70e59c07c61a3a"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "http_cidr_blocks" {
  description = "CIDR blocks allowed to reach HTTP."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = alltrue([for cidr in var.http_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "http_cidr_blocks must contain valid CIDR ranges."
  }
}

variable "enable_ssh" {
  description = "Whether to create SSH ingress for environments that still require it."
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to reach SSH."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = alltrue([for cidr in var.ssh_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "ssh_cidr_blocks must contain valid CIDR ranges."
  }
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
