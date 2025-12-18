variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the GKE cluster"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the GKE cluster (used if regional=false)"
  type        = string
  default     = "us-central1-a"
}

variable "regional" {
  description = "Create a regional cluster (recommended for production)"
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "greenfield-cluster"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "pods_cidr" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr" {
  description = "CIDR block for services"
  type        = string
  default     = "10.2.0.0/16"
}

variable "use_arm" {
  description = "Use ARM-based instances (Tau T2A)"
  type        = bool
  default     = true
}

variable "arm_machine_type" {
  description = "ARM machine type (Tau T2A processors)"
  type        = string
  default     = "t2a-standard-2"  # 2 vCPU, 8 GiB RAM
  # Other options: t2a-standard-4 (4 vCPU, 16 GiB), t2a-standard-8 (8 vCPU, 32 GiB)
}

variable "x86_machine_type" {
  description = "x86 machine type (fallback option)"
  type        = string
  default     = "e2-standard-2"  # 2 vCPU, 8 GiB RAM
}

variable "node_count" {
  description = "Initial number of nodes per zone"
  type        = number
  default     = 3
}

variable "node_min_count" {
  description = "Minimum number of nodes per zone"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of nodes per zone"
  type        = number
  default     = 6
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
