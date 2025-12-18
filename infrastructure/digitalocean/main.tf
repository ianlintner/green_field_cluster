terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# VPC for the cluster
resource "digitalocean_vpc" "main" {
  name     = "${var.cluster_name}-vpc"
  region   = var.region
  ip_range = var.vpc_cidr
}

# Kubernetes Cluster
resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = var.kubernetes_version
  vpc_uuid = digitalocean_vpc.main.id

  node_pool {
    name       = "${var.cluster_name}-pool"
    size       = var.node_size
    node_count = var.node_count
    auto_scale = true
    min_nodes  = var.node_min_count
    max_nodes  = var.node_max_count

    tags = ["greenfield", var.environment]
  }

  tags = ["greenfield", var.environment, "terraform"]
}
