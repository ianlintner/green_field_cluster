output "cluster_id" {
  description = "Kubernetes cluster ID"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for Kubernetes API"
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "cluster_status" {
  description = "Current status of the cluster"
  value       = digitalocean_kubernetes_cluster.main.status
}

output "region" {
  description = "DigitalOcean region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = digitalocean_vpc.main.id
}

output "kubeconfig" {
  description = "Kubeconfig file content"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}

output "configure_kubectl" {
  description = "Configure kubectl instructions"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.main.name}"
}
