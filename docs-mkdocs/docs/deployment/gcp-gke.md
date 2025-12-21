# GCP GKE Deployment

This guide covers deploying Greenfield Cluster on Google Kubernetes Engine (GKE) with ARM Tau T2A instances for optimal price/performance.

## Overview

Google Kubernetes Engine provides managed Kubernetes clusters on GCP, offering:

- **Managed Control Plane**: Google handles the Kubernetes control plane
- **ARM Tau T2A Support**: Up to 50% price-performance advantage
- **GCP Integration**: Native integration with Cloud services
- **Auto-scaling**: Node auto-provisioning and cluster autoscaler
- **Autopilot Mode**: Fully managed Kubernetes (optional)

## Prerequisites

- GCP account with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) configured
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0 (for IaC)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.24+
- GCP project with necessary APIs enabled

## Deployment Options

### Option 1: Terraform (Recommended)

Use our Terraform configuration for automated, reproducible deployments.

#### Quick Start

```bash
# Navigate to GCP infrastructure directory
cd infrastructure/gcp/

# Login and set project
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com compute.googleapis.com

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Create cluster (takes 5-10 minutes)
terraform apply

# Configure kubectl
gcloud container clusters get-credentials greenfield-cluster \
  --zone us-central1-a

# Verify cluster
kubectl get nodes
```

#### Custom Configuration

Create `terraform.tfvars`:

```hcl
project_id      = "your-gcp-project"
cluster_name    = "greenfield-cluster"
region          = "us-central1"
zone            = "us-central1-a"
environment     = "dev"
use_arm         = true           # Use ARM Tau T2A instances
regional        = false          # Zonal cluster (cheaper)
node_count      = 3
arm_machine_type = "t2a-standard-2"  # 2 vCPU, 8GB RAM
```

Apply configuration:

```bash
terraform apply
```

See the complete [GCP Infrastructure Guide](../../../infrastructure/gcp/README.md) for all options.

### Option 2: gcloud CLI

Quick cluster creation using gcloud command-line tool.

#### Basic Cluster with ARM

```bash
gcloud container clusters create greenfield-cluster \
  --zone us-central1-a \
  --machine-type t2a-standard-2 \
  --num-nodes 3 \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 6 \
  --disk-size 50 \
  --disk-type pd-standard \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool=YOUR_PROJECT_ID.svc.id.goog
```

#### Regional Cluster (High Availability)

```bash
gcloud container clusters create greenfield-cluster \
  --region us-central1 \
  --machine-type t2a-standard-2 \
  --num-nodes 1 \
  --node-locations us-central1-a,us-central1-b,us-central1-c \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 9 \
  --enable-autorepair \
  --enable-autoupgrade
```

### Option 3: GCP Console

Manual creation through GCP Console:

1. **Navigate**: Console → Kubernetes Engine → Clusters
2. **Create**: Click "Create"
3. **Mode**: Standard or Autopilot
4. **Configure**:
   - Name: greenfield-cluster
   - Location type: Zonal (us-central1-a) or Regional
   - Kubernetes version: 1.28 or later
5. **Node Pools**:
   - Machine type: t2a-standard-2 (ARM)
   - Number of nodes: 3
   - Autoscaling: Min 2, Max 6
   - Disk: 50 GB standard persistent disk
6. **Create**: Wait 5-10 minutes

## Architecture

### Default Configuration

| Component | Configuration |
|-----------|---------------|
| **Region** | us-central1 (configurable) |
| **Zone** | us-central1-a (or regional) |
| **K8s Version** | 1.28+ (auto-upgrade enabled) |
| **Control Plane** | Managed by Google |
| **Machine Type** | t2a-standard-2 (ARM Tau T2A) |
| **Node Count** | 2-6 (3 desired, auto-scaling) |
| **Node Storage** | 50 GB pd-standard |
| **Release Channel** | Regular (balanced updates) |

### ARM vs x86 Instance Options

#### ARM (Tau T2A) - Default

**Advantages:**
- Up to 50% better price-performance
- Latest ARM architecture (Ampere Altra)
- Energy efficient

**Machine Types:**
- `t2a-standard-2`: 2 vCPU, 8 GB RAM (~$0.0536/hr)
- `t2a-standard-4`: 4 vCPU, 16 GB RAM (~$0.1072/hr)
- `t2a-standard-8`: 8 vCPU, 32 GB RAM (~$0.2144/hr)

#### x86 (N2/E2) - Fallback

**Machine Types:**
- `e2-standard-2`: 2 vCPU, 8 GB RAM (~$0.0670/hr)
- `n2-standard-2`: 2 vCPU, 8 GB RAM (~$0.0971/hr)
- `e2-standard-4`: 4 vCPU, 16 GB RAM (~$0.1340/hr)

### Cluster Types

#### Zonal Cluster (Default)

- **Cost**: Lower (single zone)
- **Availability**: Single zone
- **Use case**: Development, testing, cost-sensitive workloads

```bash
--zone us-central1-a
```

#### Regional Cluster

- **Cost**: Higher (~3x node costs)
- **Availability**: Multi-zone (3 zones)
- **Use case**: Production, high availability

```bash
--region us-central1 \
--node-locations us-central1-a,us-central1-b,us-central1-c
```

## Deploying Greenfield Cluster

After creating your GKE cluster:

### 1. Configure kubectl

```bash
# Get credentials
gcloud container clusters get-credentials greenfield-cluster \
  --zone us-central1-a \
  --project YOUR_PROJECT_ID

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

**GKE Ingress (HTTP(S) Load Balancer):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: greenfield-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "greenfield-ip"
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fastapi-app
                port:
                  number: 8000
```

**NGINX Ingress Controller:**

```bash
# Install NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

## Cost Optimization

### Estimated Monthly Costs

**Development (t2a-standard-2, 3 nodes, zonal):**
- Control Plane: Free (zonal)
- Worker Nodes: ~$117 (3 × $0.0536/hr × 730hr)
- Persistent Disks: ~$15 (300GB × $0.04/GB-month)
- **Total: ~$132/month**

**Production (t2a-standard-4, 5 nodes, regional):**
- Control Plane: ~$73 (regional cluster fee)
- Worker Nodes: ~$1,566 (15 nodes across 3 zones × $0.1072/hr × 730hr)
- Persistent Disks: ~$50 (500GB)
- Load Balancer: ~$18
- **Total: ~$1,707/month** (or ~$570/month for zonal)

### Cost Reduction Tips

1. **Use ARM Tau T2A**: Up to 50% savings
2. **Zonal vs Regional**: Regional costs 3x more for nodes
3. **Preemptible/Spot VMs**: Up to 91% discount
4. **Committed Use Discounts**: 37-57% savings with 1-3 year commitments
5. **Autopilot**: Pay only for running pods (good for variable workloads)
6. **Right-sizing**: Use smaller machine types with autoscaling
7. **Standard Persistent Disk**: Use pd-standard instead of pd-ssd when possible

### Enable Preemptible Nodes

For fault-tolerant workloads:

```bash
gcloud container node-pools create spot-pool \
  --cluster greenfield-cluster \
  --zone us-central1-a \
  --machine-type t2a-standard-2 \
  --spot \
  --num-nodes 2 \
  --enable-autoscaling \
  --min-nodes 0 \
  --max-nodes 5
```

### GKE Autopilot

Fully managed option (pay per pod):

```bash
gcloud container clusters create-auto greenfield-cluster \
  --region us-central1 \
  --release-channel regular
```

## Monitoring and Operations

### Cloud Monitoring (formerly Stackdriver)

Enabled by default on GKE. View metrics:

```bash
# View in console
# Console → Monitoring → GKE

# Or use gcloud
gcloud container clusters describe greenfield-cluster \
  --zone us-central1-a \
  --format="value(monitoringConfig)"
```

### Cluster Autoscaler

Already enabled if created with `--enable-autoscaling`. Configure:

```bash
gcloud container clusters update greenfield-cluster \
  --zone us-central1-a \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 10 \
  --node-pool default-pool
```

### Vertical Pod Autoscaler

Automatically adjust pod resources:

```bash
# Enable VPA
gcloud container clusters update greenfield-cluster \
  --zone us-central1-a \
  --enable-vertical-pod-autoscaling
```

### Node Auto-Provisioning

Automatically create new node pools:

```bash
gcloud container clusters update greenfield-cluster \
  --zone us-central1-a \
  --enable-autoprovisioning \
  --min-cpu 1 \
  --max-cpu 100 \
  --min-memory 1 \
  --max-memory 1000
```

## Security Best Practices

1. **Workload Identity**: Use GCP IAM for pod authentication
2. **Private Clusters**: Control plane on private IP
3. **Binary Authorization**: Ensure only trusted images run
4. **Shielded GKE Nodes**: Secure boot and vTPM
5. **Network Policies**: Restrict pod-to-pod communication
6. **GKE Sandbox**: Container isolation with gVisor
7. **Regular Updates**: Enable auto-upgrade

### Enable Workload Identity

```bash
# Already enabled in Terraform config
gcloud container clusters update greenfield-cluster \
  --zone us-central1-a \
  --workload-pool=YOUR_PROJECT_ID.svc.id.goog

# Create service account binding
kubectl annotate serviceaccount default \
  iam.gke.io/gcp-service-account=GSA_NAME@PROJECT_ID.iam.gserviceaccount.com \
  --namespace greenfield
```

### Private Cluster

```bash
gcloud container clusters create greenfield-cluster \
  --zone us-central1-a \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr 172.16.0.0/28
```

## Troubleshooting

### Nodes Not Ready

```bash
# Check node status
kubectl get nodes
kubectl describe node NODE_NAME

# Check node pool
gcloud container node-pools list \
  --cluster greenfield-cluster \
  --zone us-central1-a

# View logs
gcloud logging read "resource.type=k8s_node"
```

### Pods Stuck in Pending

```bash
# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes

# Scale node pool
gcloud container clusters resize greenfield-cluster \
  --zone us-central1-a \
  --num-nodes 5 \
  --node-pool default-pool
```

### Persistent Volume Issues

```bash
# Check storage classes
kubectl get storageclass

# Check PVC status
kubectl get pvc -n greenfield

# View persistent disk
gcloud compute disks list
```

### Quota Issues

```bash
# Check quotas
gcloud compute project-info describe --project YOUR_PROJECT_ID

# Request quota increase
# Console → IAM & Admin → Quotas
```

## Cleanup

### Terraform

```bash
# Delete Greenfield resources first
kubectl delete -k kustomize/base/

# Destroy GKE cluster
cd infrastructure/gcp/
terraform destroy
```

### gcloud

```bash
# Delete cluster
gcloud container clusters delete greenfield-cluster \
  --zone us-central1-a

# Clean up persistent disks (if any remain)
gcloud compute disks list --filter="name~greenfield"
gcloud compute disks delete DISK_NAME --zone us-central1-a
```

## GKE vs Alternatives

| Feature | GKE Standard | GKE Autopilot | Competitor |
|---------|--------------|---------------|------------|
| Control Plane | Managed | Managed | Varies |
| Nodes | You manage | Google manages | You manage |
| Cost Model | Per node-hour | Per pod-resources | Per node-hour |
| Flexibility | High | Medium | High |
| Ops Burden | Medium | Low | Medium-High |
| Best For | Custom needs | Simple deployments | Varies |

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GKE Best Practices](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke)
- [Tau T2A Information](https://cloud.google.com/compute/docs/general-purpose-machines#t2a_machines)
- [GKE Pricing Calculator](https://cloud.google.com/products/calculator)

## Next Steps

- [AWS EKS Deployment](aws-eks.md)
- [Azure AKS Deployment](azure-aks.md)
- [Deployment Methods](methods.md)
- [Security Configuration](../security/overview.md)
