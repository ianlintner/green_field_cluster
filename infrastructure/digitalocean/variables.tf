variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region for the cluster"
  type        = string
  default     = "nyc1"
  # Other options: nyc3, sfo3, ams3, sgp1, lon1, fra1, tor1, blr1, syd1
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "greenfield-cluster"
}

variable "kubernetes_version" {
  description = "Kubernetes version (check: doctl kubernetes options versions)"
  type        = string
  default     = "1.28.2-do.0"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "node_size" {
  description = "Droplet size for nodes"
  type        = string
  default     = "s-2vcpu-4gb"
  # Cost-effective options:
  # s-2vcpu-2gb: 2 vCPU, 2 GB RAM - $18/month (~$0.027/hour)
  # s-2vcpu-4gb: 2 vCPU, 4 GB RAM - $24/month (~$0.036/hour)
  # s-4vcpu-8gb: 4 vCPU, 8 GB RAM - $48/month (~$0.071/hour)
  # 
  # Premium CPU options (better performance):
  # c-2: 2 vCPU, 4 GB RAM - $42/month (~$0.063/hour)
  # c-4: 4 vCPU, 8 GB RAM - $84/month (~$0.126/hour)
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
