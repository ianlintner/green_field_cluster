# Azure AKS Infrastructure

This Terraform configuration creates a minimal AKS cluster for running the Greenfield project.

## Features

- **ARM Support**: Uses Ampere Altra (ARM-based) instances by default for better price/performance
- **Minimal Configuration**: Optimized for cost-effectiveness
- **Production Ready**: Auto-scaling enabled
- **Managed Identity**: Uses system-assigned managed identity

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

### 1. Login to Azure

```bash
az login
az account set --subscription "your-subscription-id"
```

### 2. Configure Variables (Optional)

Create a `terraform.tfvars` file:

```hcl
cluster_name = "my-greenfield-cluster"
location     = "East US"
environment  = "dev"
use_arm      = true  # Set to false for x86 instances
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

This will take approximately 5-10 minutes.

### 6. Configure kubectl

```bash
az aks get-credentials --resource-group greenfield-cluster-rg --name greenfield-cluster
```

Or use the output command:

```bash
$(terraform output -raw configure_kubectl)
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

- **Region**: East US
- **Node Type**: Standard_D2ps_v5 (ARM Ampere Altra) or Standard_D2s_v3 (x86)
- **Node Count**: 2-6 nodes (3 initial)
- **VNet**: 10.0.0.0/16
- **Subnet**: 10.0.1.0/24
- **Kubernetes Version**: 1.28
- **Network Plugin**: Azure CNI

### VM Sizes

#### ARM (Ampere Altra) - Default
- **Standard_D2ps_v5**: 2 vCPU, 8 GiB RAM (~$0.096/hour)
- **Standard_D4ps_v5**: 4 vCPU, 16 GiB RAM (~$0.192/hour)
- **Standard_D8ps_v5**: 8 vCPU, 32 GiB RAM (~$0.384/hour)

#### x86 - Fallback
- **Standard_D2s_v3**: 2 vCPU, 8 GiB RAM (~$0.096/hour)
- **Standard_D4s_v3**: 4 vCPU, 16 GiB RAM (~$0.192/hour)

## Cost Optimization

### Development/Testing
Use the default configuration with:
- 2-3 ARM nodes
- Auto-scaling enabled

**Estimated cost**: ~$200-300/month

### Production
For production workloads:

```hcl
node_count     = 4
node_min_count = 3
node_max_count = 10
arm_vm_size    = "Standard_D4ps_v5"
```

## Customization

### Use x86 Instances Instead of ARM

```hcl
use_arm = false
```

### Change VM Size

```hcl
arm_vm_size = "Standard_D4ps_v5"  # 4 vCPU, 16 GiB RAM
```

### Modify Node Scaling

```hcl
node_count     = 4
node_min_count = 3
node_max_count = 10
```

### Different Region

```hcl
location = "West Europe"
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

1. **Managed Identity**: Uses system-assigned managed identity (no credentials to manage)
2. **Network**: Uses Azure CNI for network integration
3. **RBAC**: AKS RBAC is enabled by default
4. **Secrets**: Use Azure Key Vault or Sealed Secrets for sensitive data
5. **Updates**: Keep Kubernetes version updated

## Troubleshooting

### Cluster Creation Fails

Check Azure service limits:
```bash
az vm list-usage --location "East US" --output table
```

### ARM VM Not Available

ARM VMs (Dps_v5 series) are available in most regions, but if not available:
```hcl
use_arm = false
```

Or check VM availability:
```bash
az vm list-skus --location "East US" --size Standard_D --output table | grep ps_v5
```

### Network Issues

Ensure the CIDR ranges don't conflict with your on-premises network or other Azure resources.

## Additional Resources

- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Azure ARM VMs](https://docs.microsoft.com/en-us/azure/virtual-machines/dpsv5-dpdsv5-series)
- [AKS Pricing](https://azure.microsoft.com/en-us/pricing/details/kubernetes-service/)
