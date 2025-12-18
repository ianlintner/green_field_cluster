variable "location" {
  description = "Azure region for the AKS cluster"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "greenfield-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "use_arm" {
  description = "Use ARM-based instances (Ampere Altra)"
  type        = bool
  default     = true
}

variable "arm_vm_size" {
  description = "ARM VM size (Ampere Altra processors)"
  type        = string
  default     = "Standard_D2ps_v5"  # 2 vCPU, 8 GiB RAM
  # Other options: Standard_D4ps_v5 (4 vCPU, 16 GiB)
}

variable "x86_vm_size" {
  description = "x86 VM size (fallback option)"
  type        = string
  default     = "Standard_D2s_v3"  # 2 vCPU, 8 GiB RAM
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 3
}

variable "node_min_count" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of nodes"
  type        = number
  default     = 6
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
