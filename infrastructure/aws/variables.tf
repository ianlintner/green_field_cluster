variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "greenfield-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (cheaper for dev/test)"
  type        = bool
  default     = true
}

variable "use_arm" {
  description = "Use ARM-based (Graviton) instances"
  type        = bool
  default     = true
}

variable "arm_instance_types" {
  description = "ARM instance types (Graviton processors)"
  type        = list(string)
  default     = ["t4g.large", "t4g.xlarge"]
}

variable "x86_instance_types" {
  description = "x86 instance types (fallback option)"
  type        = list(string)
  default     = ["t3.large", "t3.xlarge"]
}

variable "node_group_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
}

variable "node_group_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Project     = "greenfield-cluster"
    ManagedBy   = "terraform"
  }
}
