# Infrastructure Examples

This directory contains Terraform configurations and scripts to bootstrap Kubernetes clusters on various cloud providers and on-premises environments for the Greenfield Cluster project.

## 🎯 Overview

These examples provide minimal infrastructure configurations to get a Kubernetes cluster up and running quickly. They are designed to:

- **Start small**: Minimal node configurations suitable for development and testing
- **Scale up**: Can be easily modified for production workloads
- **Prefer ARM**: Use ARM instances by default for better price/performance (where available)
- **Provide options**: x86 fallback options for all configurations

## 📁 Available Providers

| Provider | Directory | ARM Support | Estimated Cost/Month | Setup Time |
|----------|-----------|-------------|---------------------|------------|
| **AWS EKS** | [aws/](aws/) | ✅ Yes (Graviton) | $200-300 | 10-15 min |
| **Azure AKS** | [azure/](azure/) | ✅ Yes (Ampere Altra) | $200-300 | 5-10 min |
| **GCP GKE** | [gcp/](gcp/) | ✅ Yes (Tau T2A) | $120-200 | 5-10 min |
| **DigitalOcean** | [digitalocean/](digitalocean/) | ❌ No | $75-150 | 3-5 min |
| **On-Premises** | [on-premises/](on-premises/) | ✅ Yes (Any ARM64) | Hardware dependent | 15-30 min |

## 🚀 Quick Start

### 1. Choose Your Provider

Navigate to the provider directory of your choice:

```bash
cd infrastructure/<provider>/
```

### 2. Configure Variables

Each provider has a `terraform.tfvars.example` or instructions in the README. Create your configuration:

```hcl
# Example for AWS
cluster_name = "my-greenfield-cluster"
aws_region   = "us-west-2"
environment  = "dev"
use_arm      = true
```

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configure kubectl

Each provider's output includes a command to configure kubectl:

```bash
# AWS
aws eks update-kubeconfig --region us-west-2 --name greenfield-cluster

# Azure
az aks get-credentials --resource-group greenfield-cluster-rg --name greenfield-cluster

# GCP
gcloud container clusters get-credentials greenfield-cluster --zone us-central1-a

# DigitalOcean
doctl kubernetes cluster kubeconfig save greenfield-cluster
```

### 5. Deploy Greenfield

```bash
# Navigate back to repository root
cd ../..

# Deploy using Kustomize
kubectl apply -k kustomize/overlays/dev/

# Or deploy using Helm
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## 💰 Cost Comparison

### Development/Testing Configuration

| Provider | Instance Type | Nodes | Monthly Cost | Notes |
|----------|--------------|-------|--------------|-------|
| AWS | t4g.large (ARM) | 3 | ~$200-250 | + EKS control plane ($73) |
| Azure | D2ps_v5 (ARM) | 3 | ~$200-250 | Free control plane |
| GCP | t2a-standard-2 (ARM) | 3 | ~$120-150 | + GKE control plane (~$73) |
| DigitalOcean | s-2vcpu-4gb | 3 | ~$75-100 | Free control plane |

### Production Configuration

| Provider | Instance Type | Nodes | Monthly Cost | Notes |
|----------|--------------|-------|--------------|-------|
| AWS | t4g.xlarge (ARM) | 5 | ~$500-600 | Regional, HA setup |
| Azure | D4ps_v5 (ARM) | 5 | ~$500-600 | Regional, HA setup |
| GCP | t2a-standard-4 (ARM) | 5 | ~$350-450 | Regional cluster |
| DigitalOcean | s-4vcpu-8gb | 5 | ~$250-300 | HA node pool |

**Note**: Costs are estimates and don't include data transfer, storage, or load balancer costs.

## 🦾 ARM vs x86

### ARM Instances (Default)

**Advantages:**
- **Cost**: 15-20% cheaper than equivalent x86 instances
- **Performance/Watt**: Better energy efficiency
- **Modern Architecture**: Latest ARM processors (Graviton3, Ampere Altra, Tau T2A)

**Considerations:**
- Ensure all container images support ARM64 (multi-arch)
- Some legacy software may not be available

### x86 Instances (Fallback)

All configurations provide x86 options. Set `use_arm = false` to use x86 instances.

## 🏗️ Architecture Details

### Minimal Configuration (All Providers)

- **Control Plane**: Managed by provider (AWS EKS, Azure AKS, GCP GKE, DO DOKS)
- **Worker Nodes**: 2-6 nodes (3 initial, auto-scaling enabled)
- **Instance Size**: 2 vCPU, 8GB RAM (or equivalent)
- **Storage**: 50GB per node, with persistent volume support
- **Networking**: Private networking with CNI

### What's Included

All configurations include:
- ✅ Kubernetes cluster (v1.28+)
- ✅ Auto-scaling node pools
- ✅ Persistent volume support
- ✅ Load balancer integration
- ✅ Private networking
- ✅ Managed control plane

## 🔐 Security Considerations

1. **Credentials**: Keep cloud provider credentials secure
2. **State Files**: Store Terraform state remotely (S3, Azure Blob, GCS)
3. **Secrets**: Use cloud provider secret managers or Sealed Secrets
4. **Network**: Configure firewall rules and network policies
5. **RBAC**: Enable and configure Kubernetes RBAC
6. **Updates**: Keep Kubernetes and node images updated

### Remote State Example (S3)

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "greenfield/terraform.tfstate"
    region = "us-west-2"
  }
}
```

## 🛠️ Customization

All configurations are designed to be minimal but production-ready. Common customizations:

### Scale Up for Production

```hcl
# Increase node count and size
node_count           = 5
node_min_count       = 3
node_max_count       = 10
arm_instance_types   = ["t4g.xlarge"]  # AWS example
```

### Use x86 Instead of ARM

```hcl
use_arm = false
```

### Multi-Region/Zone Setup

```hcl
# GCP example
regional = true  # Spans multiple zones
```

### Add Node Labels/Taints

Check provider-specific documentation for node customization options.

## 📋 Prerequisites

### All Providers
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Provider-Specific
- **AWS**: [AWS CLI](https://aws.amazon.com/cli/) configured
- **Azure**: [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/) logged in
- **GCP**: [gcloud CLI](https://cloud.google.com/sdk/) configured
- **DigitalOcean**: [doctl CLI](https://docs.digitalocean.com/reference/doctl/) (optional) and API token
- **On-Premises**: Linux servers with network connectivity

## 🧹 Cleanup

To destroy the infrastructure and avoid ongoing charges:

```bash
# First, delete Kubernetes resources
kubectl delete -k ../../kustomize/overlays/dev/

# Then destroy infrastructure
terraform destroy
```

**⚠️ Warning**: This will delete all resources including persistent volumes and data!

## 🆘 Troubleshooting

### Terraform Init Fails
```bash
# Clear cache and retry
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Cluster Creation Fails
Check cloud provider quotas and service limits:
```bash
# AWS
aws service-quotas list-service-quotas --service-code eks

# Azure
az vm list-usage --location eastus

# GCP
gcloud compute project-info describe
```

### kubectl Connection Issues
Verify kubeconfig is correctly set:
```bash
kubectl config current-context
kubectl cluster-info
```

## 📚 Additional Resources

### Provider Documentation
- [AWS EKS](https://aws.amazon.com/eks/)
- [Azure AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- [GCP GKE](https://cloud.google.com/kubernetes-engine)
- [DigitalOcean Kubernetes](https://www.digitalocean.com/products/kubernetes)

### Terraform Modules
- [AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws)
- [Azure AKS Module](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [GCP GKE Module](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [DigitalOcean Module](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs/resources/kubernetes_cluster)

### Kubernetes Resources
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

## 🤝 Contributing

Contributions are welcome! If you have improvements or additional provider examples:

1. Follow the existing structure
2. Include detailed README
3. Test the configuration
4. Submit a pull request

## 📄 License

These configurations are provided under the MIT License. See the main repository LICENSE file for details.

## ⚠️ Important Notes

1. **These are examples**: Review and customize for your specific needs
2. **Cost awareness**: Monitor your cloud spending
3. **Security**: Follow security best practices for your environment
4. **Testing**: Test in non-production environments first
5. **Backup**: Regular backups of important data
6. **Monitoring**: Set up monitoring and alerting

## 🎓 Learning Resources

New to Terraform or Kubernetes? Start here:
- [Terraform Getting Started](https://learn.hashicorp.com/terraform)
- [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
- [Cloud Provider Kubernetes Guides](https://kubernetes.io/docs/setup/production-environment/)
