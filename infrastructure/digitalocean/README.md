# DigitalOcean Kubernetes Infrastructure

This Terraform configuration creates a minimal Kubernetes cluster on DigitalOcean for running the Greenfield project.

## Features

- **Managed Kubernetes**: Fully managed control plane (free)
- **Simple Configuration**: Easy to set up and manage
- **Auto-scaling**: Built-in node pool auto-scaling
- **Cost-effective**: Competitive pricing, especially for smaller workloads
- **Fast Provisioning**: Cluster ready in 3-5 minutes

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [doctl CLI](https://docs.digitalocean.com/reference/doctl/how-to/install/) (optional, but recommended)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- DigitalOcean account with API token

## Quick Start

### 1. Create a DigitalOcean API Token

1. Go to [API Tokens](https://cloud.digitalocean.com/account/api/tokens)
2. Generate a new token with read and write access
3. Copy the token (you'll only see it once)

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
do_token     = "your-digitalocean-api-token"
cluster_name = "greenfield-cluster"
region       = "nyc1"
environment  = "dev"
node_size    = "s-2vcpu-4gb"
```

Or set the token as an environment variable:

```bash
export TF_VAR_do_token="your-digitalocean-api-token"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan the Infrastructure

```bash
terraform plan
```

### 5. Create the Cluster

```bash
terraform apply
```

This will take approximately 3-5 minutes.

### 6. Configure kubectl

Using doctl (recommended):
```bash
doctl kubernetes cluster kubeconfig save greenfield-cluster
```

Or manually save the kubeconfig:
```bash
terraform output -raw kubeconfig > kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml
```

### 7. Verify Cluster

```bash
kubectl get nodes
```

### 8. Deploy Greenfield

```bash
# Go back to the repository root
cd ../..

# Deploy using Kustomize
kubectl apply -k kustomize/overlays/dev/

# Or deploy using Helm
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## Architecture

### Default Configuration

- **Region**: NYC1 (New York)
- **Node Size**: s-2vcpu-4gb (2 vCPU, 4 GB RAM)
- **Node Count**: 2-6 nodes (3 initial)
- **VPC**: 10.10.0.0/16
- **Kubernetes Version**: 1.28.2-do.0

### Available Droplet Sizes

#### Standard Droplets (Best for general workloads)
| Size | vCPU | RAM | Storage | Price/month | Price/hour |
|------|------|-----|---------|-------------|------------|
| s-2vcpu-2gb | 2 | 2 GB | 60 GB | $18 | ~$0.027 |
| s-2vcpu-4gb | 2 | 4 GB | 80 GB | $24 | ~$0.036 |
| s-4vcpu-8gb | 4 | 8 GB | 160 GB | $48 | ~$0.071 |

#### Premium CPU Droplets (Better performance)
| Size | vCPU | RAM | Storage | Price/month | Price/hour |
|------|------|-----|---------|-------------|------------|
| c-2 | 2 | 4 GB | 50 GB | $42 | ~$0.063 |
| c-4 | 4 | 8 GB | 100 GB | $84 | ~$0.126 |

**Note**: DigitalOcean does not currently offer ARM-based droplets for Kubernetes.

## Cost Optimization

### Development/Testing
Minimal configuration:

```hcl
node_size      = "s-2vcpu-2gb"
node_count     = 2
node_min_count = 2
node_max_count = 4
```

**Estimated cost**: ~$35-75/month (control plane is free!)

### Production
Recommended configuration:

```hcl
node_size      = "s-4vcpu-8gb"
node_count     = 3
node_min_count = 3
node_max_count = 8
```

**Estimated cost**: ~$145-385/month

## Customization

### Change Node Size

```hcl
node_size = "s-4vcpu-8gb"  # 4 vCPU, 8 GB RAM
```

### Modify Node Scaling

```hcl
node_count     = 4
node_min_count = 3
node_max_count = 10
```

### Different Region

Available regions: nyc1, nyc3, sfo3, ams3, sgp1, lon1, fra1, tor1, blr1, syd1

```hcl
region = "sfo3"  # San Francisco
```

Check available regions:
```bash
doctl kubernetes options regions
```

### Change Kubernetes Version

Check available versions:
```bash
doctl kubernetes options versions
```

Then update:
```hcl
kubernetes_version = "1.28.2-do.0"
```

## Cleanup

To destroy the infrastructure:

```bash
# First, delete all Kubernetes resources
kubectl delete -k ../../kustomize/overlays/dev/

# Then destroy the infrastructure
terraform destroy
```

**Warning**: This will delete all resources including persistent volumes!

## Security Considerations

1. **API Token**: Keep your DO token secure, use environment variables
2. **VPC**: Cluster nodes are in a private VPC
3. **Secrets**: Use DigitalOcean Spaces or Sealed Secrets for sensitive data
4. **Updates**: Keep Kubernetes version updated
5. **Firewall**: Configure DigitalOcean Cloud Firewall for additional protection

## Troubleshooting

### Cluster Creation Fails

Check your account limits:
```bash
doctl account get
```

### Unable to Connect

Verify cluster status:
```bash
doctl kubernetes cluster list
doctl kubernetes cluster get greenfield-cluster
```

### Node Issues

Check node pool status:
```bash
kubectl get nodes -o wide
doctl kubernetes cluster node-pool list greenfield-cluster
```

## Advantages of DigitalOcean

1. **Simple Pricing**: Clear, predictable pricing
2. **Free Control Plane**: Only pay for worker nodes
3. **Fast Provisioning**: Clusters ready in minutes
4. **Managed**: Automatic updates and maintenance
5. **Good Documentation**: Excellent tutorials and guides

## Additional Resources

- [DigitalOcean Kubernetes Documentation](https://docs.digitalocean.com/products/kubernetes/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- [DOKS Pricing](https://www.digitalocean.com/pricing/kubernetes)
- [DOKS Tutorials](https://docs.digitalocean.com/products/kubernetes/how-to/)
