# GCP GKE Infrastructure

This Terraform configuration creates a minimal GKE cluster for running the Greenfield project.

## Features

- **ARM Support**: Uses Tau T2A (ARM-based) instances by default for better price/performance
- **Minimal Configuration**: Zonal cluster for cost-effectiveness (regional option available)
- **Production Ready**: Auto-scaling and auto-repair enabled
- **Workload Identity**: Enabled for secure pod authentication

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- A GCP project with billing enabled

## Quick Start

### 1. Setup GCP

```bash
# Login to GCP
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
project_id   = "your-gcp-project-id"
cluster_name = "greenfield-cluster"
region       = "us-central1"
zone         = "us-central1-a"
environment  = "dev"
use_arm      = true  # Set to false for x86 instances
regional     = false # Set to true for regional cluster (higher availability, higher cost)
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
gcloud container clusters get-credentials greenfield-cluster --zone us-central1-a
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

- **Region**: us-central1 (zonal cluster in us-central1-a)
- **Node Type**: t2a-standard-2 (ARM Tau T2A) or e2-standard-2 (x86)
- **Node Count**: 2-6 nodes per zone (3 initial)
- **VPC**: Custom VPC with secondary IP ranges
- **Network**: VPC-native cluster with alias IPs

### Machine Types

#### ARM (Tau T2A) - Default
- **t2a-standard-2**: 2 vCPU, 8 GiB RAM (~$0.0536/hour)
- **t2a-standard-4**: 4 vCPU, 16 GiB RAM (~$0.1072/hour)
- **t2a-standard-8**: 8 vCPU, 32 GiB RAM (~$0.2144/hour)

#### x86 - Fallback
- **e2-standard-2**: 2 vCPU, 8 GiB RAM (~$0.067/hour)
- **e2-standard-4**: 4 vCPU, 16 GiB RAM (~$0.134/hour)

## Cost Optimization

### Development/Testing (Zonal Cluster)
Use the default configuration:
- Zonal cluster (single zone)
- 2-3 ARM nodes
- Auto-scaling enabled

**Estimated cost**: ~$120-200/month

### Production (Regional Cluster)
For high availability:

```hcl
regional       = true
node_count     = 3  # Per zone (will be replicated across 3 zones)
node_min_count = 2
node_max_count = 6
```

**Note**: Regional clusters are more expensive but provide higher availability.

## Customization

### Use x86 Instances Instead of ARM

```hcl
use_arm = false
```

### Change Machine Type

```hcl
arm_machine_type = "t2a-standard-4"  # 4 vCPU, 16 GiB RAM
```

### Create Regional Cluster

```hcl
regional = true  # Cluster will span 3 zones in the region
```

### Modify Node Scaling

```hcl
node_count     = 4
node_min_count = 3
node_max_count = 10
```

### Different Region

```hcl
region = "europe-west1"
zone   = "europe-west1-b"  # Only used if regional=false
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

1. **Workload Identity**: Enabled for secure pod-to-GCP authentication
2. **Network**: VPC-native cluster with private nodes option available
3. **Auto-updates**: Nodes auto-update and auto-repair enabled
4. **Secrets**: Use GCP Secret Manager or Sealed Secrets for sensitive data
5. **Least Privilege**: Node service accounts follow principle of least privilege

## Troubleshooting

### Insufficient Quota

Check your quotas:
```bash
gcloud compute project-info describe --project YOUR_PROJECT_ID
```

Increase quotas if needed through the GCP Console.

### ARM Machines Not Available

Tau T2A machines are available in most regions. Check availability:
```bash
gcloud compute machine-types list --filter="name:t2a" --zones=us-central1-a
```

If not available in your zone, either:
- Use a different zone
- Set `use_arm = false`

### API Not Enabled

Ensure all required APIs are enabled:
```bash
gcloud services enable container.googleapis.com compute.googleapis.com
```

## Cost Comparison

### Zonal vs Regional

| Configuration | Nodes | Monthly Cost (approx) |
|--------------|-------|----------------------|
| Zonal (3 nodes) | 3 | ~$120-150 |
| Regional (3 nodes/zone) | 9 total | ~$350-450 |

**Tip**: Use zonal for development/testing, regional for production.

## Additional Resources

- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Tau T2A VMs](https://cloud.google.com/compute/docs/general-purpose-machines#t2a_machines)
- [GKE Pricing](https://cloud.google.com/kubernetes-engine/pricing)
