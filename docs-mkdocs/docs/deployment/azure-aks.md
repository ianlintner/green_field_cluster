# Azure AKS Deployment

This guide covers deploying Greenfield Cluster on Azure Kubernetes Service (AKS) with ARM Ampere Altra instances for optimal price/performance.

## Overview

Azure Kubernetes Service provides managed Kubernetes clusters on Microsoft Azure, offering:

- **Managed Control Plane**: Azure handles the Kubernetes control plane (free)
- **ARM Ampere Support**: Better price-performance with Ampere Altra processors
- **Azure Integration**: Native integration with Azure services
- **Availability Zones**: Multi-zone deployments for high availability
- **Azure Monitor**: Built-in monitoring and logging

## Prerequisites

- Azure subscription with appropriate permissions
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) v2.50+
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0 (for IaC)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.24+

## Deployment Options

### Option 1: Terraform (Recommended)

Use our Terraform configuration for automated, reproducible deployments.

#### Quick Start

```bash
# Navigate to Azure infrastructure directory
cd infrastructure/azure/

# Login to Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Create cluster (takes 5-10 minutes)
terraform apply

# Configure kubectl
az aks get-credentials \
  --resource-group greenfield-cluster-rg \
  --name greenfield-cluster

# Verify cluster
kubectl get nodes
```

#### Custom Configuration

Create `terraform.tfvars`:

```hcl
cluster_name    = "greenfield-cluster"
location        = "East US"
resource_group  = "greenfield-rg"
environment     = "dev"
use_arm         = true                    # Use ARM Ampere Altra
node_count      = 3
arm_node_size   = "Standard_D2ps_v5"     # 2 vCPU, 8GB RAM
kubernetes_version = "1.28"
```

Apply configuration:

```bash
terraform apply
```

See the complete [Azure Infrastructure Guide](../../../infrastructure/azure/README.md) for all options.

### Option 2: Azure CLI

Quick cluster creation using az command-line tool.

#### Basic Cluster with ARM

```bash
# Create resource group
az group create \
  --name greenfield-rg \
  --location eastus

# Create AKS cluster with ARM
az aks create \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --node-count 3 \
  --node-vm-size Standard_D2ps_v5 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 6 \
  --network-plugin azure \
  --enable-addons monitoring
```

#### Multi-Zone Cluster (High Availability)

```bash
az aks create \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --node-count 3 \
  --zones 1 2 3 \
  --node-vm-size Standard_D2ps_v5 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 9
```

### Option 3: Azure Portal

Manual creation through Azure Portal:

1. **Navigate**: Portal → Kubernetes services → Create
2. **Basics**:
   - Subscription: Select subscription
   - Resource group: Create greenfield-rg
   - Cluster name: greenfield-cluster
   - Region: East US
   - Kubernetes version: 1.28 or later
3. **Node Pools**:
   - Node size: Standard_D2ps_v5 (ARM)
   - Scale method: Autoscale
   - Node count: Min 2, Max 6, Initial 3
4. **Networking**:
   - Network configuration: Azure CNI
   - DNS name prefix: greenfield
5. **Integrations**:
   - Container monitoring: Enabled
   - Azure Policy: Optional
6. **Review + Create**: Validate and create

## Architecture

### Default Configuration

| Component | Configuration |
|-----------|---------------|
| **Region** | East US (configurable) |
| **K8s Version** | 1.28+ (auto-upgrade available) |
| **Control Plane** | Managed by Azure (Free) |
| **Node Size** | Standard_D2ps_v5 (ARM Ampere) |
| **Node Count** | 2-6 (3 desired, auto-scaling) |
| **Node Storage** | 128 GB managed disk |
| **Network Plugin** | Azure CNI |
| **Identity** | System-assigned managed identity |

### ARM vs x86 VM Options

#### ARM (Ampere Altra) - Default

**Advantages:**
- Better price-performance ratio
- Modern ARM architecture
- Energy efficient

**VM Sizes (Dps_v5 series):**
- `Standard_D2ps_v5`: 2 vCPU, 8 GB RAM (~$0.096/hr)
- `Standard_D4ps_v5`: 4 vCPU, 16 GB RAM (~$0.192/hr)
- `Standard_D8ps_v5`: 8 vCPU, 32 GB RAM (~$0.384/hr)

#### x86 (Intel/AMD) - Fallback

**VM Sizes (Ds_v5 series):**
- `Standard_D2s_v5`: 2 vCPU, 8 GB RAM (~$0.096/hr)
- `Standard_D4s_v5`: 4 vCPU, 16 GB RAM (~$0.192/hr)
- `Standard_D2s_v3`: 2 vCPU, 8 GB RAM (~$0.096/hr)

**When to use x86:**
- Applications requiring x86 architecture
- Legacy software without ARM support

### Network Architecture

```
┌──────────────────────────────────────────────┐
│           Azure Virtual Network              │
│              10.0.0.0/16                     │
│  ┌────────────────────────────────────────┐  │
│  │      AKS Subnet 10.0.1.0/24           │  │
│  │                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────┐│  │
│  │  │  Node 1  │  │  Node 2  │  │Node 3││  │
│  │  │  (Zone 1)│  │  (Zone 2)│  │(Z 3) ││  │
│  │  └──────────┘  └──────────┘  └──────┘│  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

## Deploying Greenfield Cluster

After creating your AKS cluster:

### 1. Configure kubectl

```bash
# Get credentials
az aks get-credentials \
  --resource-group greenfield-cluster-rg \
  --name greenfield-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 2. Deploy Greenfield

**Using Kustomize:**

```bash
# Deploy base configuration
kubectl apply -k kustomize/base/

# Or use environment overlay
kubectl apply -k kustomize/overlays/prod/
```

**Using Helm:**

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values helm/greenfield-cluster/values-prod.yaml
```

### 3. Configure Ingress (Optional)

**NGINX Ingress Controller:**

```bash
# Install NGINX ingress with Azure annotations
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

**Application Gateway Ingress Controller:**

```bash
# Enable AGIC addon
az aks enable-addons \
  --resource-group greenfield-cluster-rg \
  --name greenfield-cluster \
  --addons ingress-appgw \
  --appgw-name greenfield-appgw \
  --appgw-subnet-cidr "10.0.2.0/24"
```

## Cost Optimization

### Estimated Monthly Costs

**Development (Standard_D2ps_v5, 3 nodes):**
- Control Plane: Free
- Worker Nodes: ~$210 (3 × $0.096/hr × 730hr)
- Managed Disks: ~$15 (300GB standard SSD)
- **Total: ~$225/month**

**Production (Standard_D4ps_v5, 5 nodes, multi-zone):**
- Control Plane: Free
- Worker Nodes: ~$700 (5 × $0.192/hr × 730hr)
- Managed Disks: ~$40 (500GB)
- Load Balancer: ~$20
- **Total: ~$760/month**

### Cost Reduction Tips

1. **Use ARM Instances**: Similar price, better performance
2. **Spot Instances**: Up to 90% savings for interruptible workloads
3. **Reserved Instances**: 1-3 year commitments for 20-72% savings
4. **Auto-shutdown**: Dev/test clusters during off-hours
5. **Right-sizing**: Use cluster autoscaler to scale down
6. **Azure Hybrid Benefit**: Save on Windows node pools
7. **Standard vs Premium Disks**: Use standard SSD when possible

### Enable Spot Node Pool

For fault-tolerant workloads:

```bash
az aks nodepool add \
  --resource-group greenfield-rg \
  --cluster-name greenfield-cluster \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 2 \
  --min-count 0 \
  --max-count 5 \
  --enable-cluster-autoscaler \
  --node-vm-size Standard_D2ps_v5
```

### Auto-Start/Stop

For dev/test environments:

```bash
# Stop cluster (preserves configuration)
az aks stop \
  --resource-group greenfield-rg \
  --name greenfield-cluster

# Start cluster
az aks start \
  --resource-group greenfield-rg \
  --name greenfield-cluster
```

## Monitoring and Operations

### Azure Monitor

Enabled by default. View metrics:

```bash
# View cluster metrics
az aks show \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --query "addonProfiles.omsagent"

# Access in portal
# Portal → Kubernetes services → greenfield-cluster → Insights
```

### Cluster Autoscaler

If enabled during creation, configure:

```bash
az aks update \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 10
```

### Node Auto-Repair

Automatically enabled on AKS. Check status:

```bash
az aks show \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --query "agentPoolProfiles[].enableAutoScaling"
```

### Upgrade Cluster

```bash
# Check available versions
az aks get-upgrades \
  --resource-group greenfield-rg \
  --name greenfield-cluster

# Upgrade cluster
az aks upgrade \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --kubernetes-version 1.29.0
```

## Security Best Practices

1. **Managed Identity**: Use instead of service principals
2. **Azure AD Integration**: RBAC with Azure AD
3. **Network Policies**: Restrict pod-to-pod communication
4. **Private Cluster**: Control plane on private IP
5. **Azure Policy**: Enforce security policies
6. **Key Vault Integration**: Store secrets in Azure Key Vault
7. **Regular Updates**: Enable auto-upgrade

### Enable Azure AD Integration

```bash
az aks update \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --enable-aad \
  --aad-admin-group-object-ids GROUP_ID
```

### Private Cluster

```bash
az aks create \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --enable-private-cluster \
  --node-count 3
```

### Azure Key Vault Integration

```bash
# Enable Key Vault secrets provider
az aks enable-addons \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --addons azure-keyvault-secrets-provider
```

## Troubleshooting

### Nodes Not Ready

```bash
# Check node status
kubectl get nodes
kubectl describe node NODE_NAME

# Check node pool
az aks nodepool list \
  --resource-group greenfield-rg \
  --cluster-name greenfield-cluster

# View activity log
az monitor activity-log list \
  --resource-group greenfield-rg \
  --offset 1h
```

### Pods Stuck in Pending

```bash
# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes

# Scale node pool
az aks nodepool scale \
  --resource-group greenfield-rg \
  --cluster-name greenfield-cluster \
  --name nodepool1 \
  --node-count 5
```

### Disk Attachment Issues

```bash
# Check storage classes
kubectl get storageclass

# Check PVC status
kubectl get pvc -n greenfield

# List managed disks
az disk list --resource-group MC_greenfield-rg_greenfield-cluster_eastus
```

### Network Issues

```bash
# Check network plugin
az aks show \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --query networkProfile

# Check CNI configuration
kubectl get pods -n kube-system | grep azure-cni
```

## Cleanup

### Terraform

```bash
# Delete Greenfield resources first
kubectl delete -k kustomize/base/

# Destroy AKS cluster
cd infrastructure/azure/
terraform destroy
```

### Azure CLI

```bash
# Delete cluster (preserves resource group)
az aks delete \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --yes

# Delete entire resource group (removes everything)
az group delete \
  --name greenfield-rg \
  --yes --no-wait
```

## AKS Features Comparison

| Feature | Standard | Premium |
|---------|----------|---------|
| Uptime SLA | 99.5% (zone) / 99.9% (multi-zone) | 99.95% |
| Control Plane | Free | ~$730/month |
| Best For | Most workloads | Mission-critical |

## Additional Resources

- [AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Azure ARM VMs](https://azure.microsoft.com/en-us/blog/azure-virtual-machines-with-ampere-altra-arm-based-processors-generally-available/)
- [AKS Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)

## Next Steps

- [AWS EKS Deployment](aws-eks.md)
- [GCP GKE Deployment](gcp-gke.md)
- [Deployment Methods](methods.md)
- [Security Configuration](../security/overview.md)
