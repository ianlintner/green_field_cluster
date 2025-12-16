# Deployment Guide

This guide provides step-by-step instructions for deploying the Greenfield Cluster to various environments.

## 🚀 Quick Start with Infrastructure Examples

**NEW**: Ready-to-use Terraform configurations and scripts are available in the [`infrastructure/`](../infrastructure/) directory for quickly bootstrapping Kubernetes clusters on:

- **AWS EKS** (with ARM Graviton support)
- **Azure AKS** (with ARM Ampere Altra support)
- **GCP GKE** (with ARM Tau T2A support)
- **DigitalOcean Kubernetes**
- **On-Premises** (kubeadm, k3s, RKE2, OpenStack Magnum)

See the [Infrastructure README](../infrastructure/README.md) for minimal cluster setup examples.

## Table of Contents

1. [Pre-deployment Checklist](#pre-deployment-checklist)
2. [Local Development (Minikube/Kind)](#local-development)
3. [AWS EKS Deployment](#aws-eks-deployment)
4. [GCP GKE Deployment](#gcp-gke-deployment)
5. [Azure AKS Deployment](#azure-aks-deployment)
6. [Post-deployment Verification](#post-deployment-verification)

## Pre-deployment Checklist

- [ ] Kubernetes cluster is running (v1.24+)
- [ ] kubectl is installed and configured
- [ ] Cluster has sufficient resources (minimum 8 CPU, 16GB RAM)
- [ ] Storage class is available for persistent volumes
- [ ] Container registry access for custom images (if building FastAPI app)

## Local Development

### Using Minikube

```bash
# Start Minikube with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable addons
minikube addons enable storage-provisioner
minikube addons enable metrics-server

# Deploy the cluster
kubectl apply -k kustomize/overlays/dev/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=fastapi-app -n greenfield-dev --timeout=300s
```

### Using Kind

```bash
# Create a cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

# Deploy the cluster
kubectl apply -k kustomize/overlays/dev/
```

## AWS EKS Deployment

### 1. Create EKS Cluster

**Option A: Using Terraform (Recommended)**

See the complete [AWS Infrastructure Guide](../infrastructure/aws/README.md) with ARM Graviton support:

```bash
cd infrastructure/aws/
terraform init
terraform apply
aws eks update-kubeconfig --region us-west-2 --name greenfield-cluster
```

**Option B: Using eksctl**

```bash
eksctl create cluster \
  --name greenfield-cluster \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type t3.xlarge \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 6 \
  --managed
```

### 2. Configure Storage

```bash
# Install EBS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.24"

# Create storage class
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
EOF
```

### 3. Install Prerequisites

```bash
# Install Istio
istioctl install --set profile=default -y

# Install Sealed Secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set-string fullnameOverride=sealed-secrets-controller
```

### 4. Build and Push FastAPI Image

```bash
# Authenticate to ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Create repository
aws ecr create-repository --repository-name fastapi-example --region us-west-2

# Build and push
cd apps/fastapi-example
docker build -t <account-id>.dkr.ecr.us-west-2.amazonaws.com/fastapi-example:latest .
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/fastapi-example:latest
```

### 5. Deploy Application

```bash
# Update image reference in kustomization
cd kustomize/overlays/prod
cat <<EOF >> kustomization.yaml
images:
  - name: fastapi-example
    newName: <account-id>.dkr.ecr.us-west-2.amazonaws.com/fastapi-example
    newTag: latest
EOF

# Deploy
kubectl apply -k kustomize/overlays/prod/
```

### 6. Configure Load Balancer

```bash
# Install AWS Load Balancer Controller
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=greenfield-cluster

# Create Ingress for services (example)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: greenfield-ingress
  namespace: greenfield-prod
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
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
EOF
```

## GCP GKE Deployment

### 1. Create GKE Cluster

**Option A: Using Terraform (Recommended)**

See the complete [GCP Infrastructure Guide](../infrastructure/gcp/README.md) with ARM Tau T2A support:

```bash
cd infrastructure/gcp/
terraform init
terraform apply
gcloud container clusters get-credentials greenfield-cluster --zone us-central1-a
```

**Option B: Using gcloud CLI**

```bash
# Create cluster
gcloud container clusters create greenfield-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 6 \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials greenfield-cluster --zone us-central1-a
```

### 2. Configure Storage

```bash
# GKE has a default storage class, but you can create a custom one
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
EOF
```

### 3. Install Prerequisites

```bash
# Install Istio
istioctl install --set profile=default -y

# Install Sealed Secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets --namespace kube-system
```

### 4. Build and Push Image

```bash
# Configure Docker for GCR
gcloud auth configure-docker

# Build and push
cd apps/fastapi-example
docker build -t gcr.io/<project-id>/fastapi-example:latest .
docker push gcr.io/<project-id>/fastapi-example:latest
```

### 5. Deploy Application

```bash
# Update image reference
cd kustomize/overlays/prod
cat <<EOF >> kustomization.yaml
images:
  - name: fastapi-example
    newName: gcr.io/<project-id>/fastapi-example
    newTag: latest
EOF

# Deploy
kubectl apply -k kustomize/overlays/prod/
```

## Azure AKS Deployment

### 1. Create AKS Cluster

**Option A: Using Terraform (Recommended)**

See the complete [Azure Infrastructure Guide](../infrastructure/azure/README.md) with ARM Ampere Altra support:

```bash
cd infrastructure/azure/
terraform init
terraform apply
az aks get-credentials --resource-group greenfield-cluster-rg --name greenfield-cluster
```

**Option B: Using Azure CLI**

```bash
# Create resource group
az group create --name greenfield-rg --location eastus

# Create AKS cluster
az aks create \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group greenfield-rg --name greenfield-cluster
```

### 2. Install Prerequisites

```bash
# Install Istio
istioctl install --set profile=default -y

# Install Sealed Secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets --namespace kube-system
```

### 3. Build and Push Image

```bash
# Create ACR
az acr create --resource-group greenfield-rg --name greenfieldacr --sku Basic

# Attach ACR to AKS
az aks update --resource-group greenfield-rg --name greenfield-cluster \
  --attach-acr greenfieldacr

# Build and push
cd apps/fastapi-example
az acr build --registry greenfieldacr --image fastapi-example:latest .
```

### 4. Deploy Application

```bash
# Update image reference
cd kustomize/overlays/prod
cat <<EOF >> kustomization.yaml
images:
  - name: fastapi-example
    newName: greenfieldacr.azurecr.io/fastapi-example
    newTag: latest
EOF

# Deploy
kubectl apply -k kustomize/overlays/prod/
```

## Post-deployment Verification

### 1. Check Pod Status

```bash
# Check all pods
kubectl get pods -n greenfield-prod

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n greenfield-prod --timeout=600s
```

### 2. Verify Services

```bash
# Check services
kubectl get svc -n greenfield-prod

# Check PVCs
kubectl get pvc -n greenfield-prod
```

### 3. Test Connectivity

```bash
# Port forward to FastAPI app
kubectl port-forward -n greenfield-prod svc/fastapi-app 8000:8000 &

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
curl http://localhost:8000/mysql
curl http://localhost:8000/mongodb
curl -X POST http://localhost:8000/kafka
```

### 4. Check Observability

```bash
# Access Grafana
kubectl port-forward -n greenfield-prod svc/grafana 3000:3000 &
# Visit http://localhost:3000 (admin/admin123)

# Access Jaeger
kubectl port-forward -n greenfield-prod svc/jaeger-query 16686:16686 &
# Visit http://localhost:16686

# Access Prometheus
kubectl port-forward -n greenfield-prod svc/prometheus 9090:9090 &
# Visit http://localhost:9090
```

### 5. Monitor Logs

```bash
# Check FastAPI logs
kubectl logs -n greenfield-prod -l app=fastapi-app -f

# Check database logs
kubectl logs -n greenfield-prod -l app=postgres -f
```

## Troubleshooting

### Pods stuck in Pending

```bash
# Check events
kubectl get events -n greenfield-prod --sort-by='.lastTimestamp'

# Check PVC status
kubectl get pvc -n greenfield-prod

# Describe pod
kubectl describe pod <pod-name> -n greenfield-prod
```

### ImagePullBackOff

```bash
# Check if image exists and is accessible
# Verify image pull secrets if using private registry
kubectl create secret docker-registry regcred \
  --docker-server=<registry-server> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n greenfield-prod
```

### CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n greenfield-prod --previous

# Check resource limits
kubectl describe pod <pod-name> -n greenfield-prod
```

## Scaling

### Horizontal Scaling

```bash
# Scale deployments
kubectl scale deployment fastapi-app --replicas=5 -n greenfield-prod

# Scale statefulsets
kubectl scale statefulset postgres --replicas=5 -n greenfield-prod
```

### Vertical Scaling

Edit the deployment/statefulset resource limits:

```bash
kubectl edit deployment fastapi-app -n greenfield-prod
```

## Backup and Disaster Recovery

### Database Backups

```bash
# PostgreSQL backup
kubectl exec -n greenfield-prod postgres-0 -- pg_dump -U postgres greenfield > backup.sql

# MongoDB backup
kubectl exec -n greenfield-prod mongodb-0 -- mongodump --out /tmp/backup

# Redis backup
kubectl exec -n greenfield-prod redis-master-0 -- redis-cli SAVE
```

### Cluster State Backup

```bash
# Backup all resources
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Use Velero for comprehensive backups
velero install --provider aws --bucket greenfield-backups
velero backup create greenfield-backup --include-namespaces greenfield-prod
```

## Security Hardening

### Network Policies

```bash
# Apply network policies to restrict traffic
kubectl apply -f network-policies/
```

### Pod Security Policies

```bash
# Enable pod security admission
# Configure in kustomize overlays
```

### Secrets Rotation

```bash
# Rotate sealed secrets regularly
# Update passwords and re-seal
kubeseal -f new-secret.yaml -w sealed-secret.yaml
kubectl apply -f sealed-secret.yaml -n greenfield-prod
```

## Monitoring and Alerts

### Configure Alertmanager

```bash
# Add alerting rules to Prometheus
# Configure alert receivers in Alertmanager
```

### Set up Dashboards

1. Access Grafana
2. Import dashboards for:
   - Kubernetes cluster monitoring
   - Database monitoring
   - Application metrics
   - Istio service mesh

## Maintenance

### Updates

```bash
# Update Kubernetes manifests
git pull
kubectl apply -k kustomize/overlays/prod/

# Rolling update strategy is used by default
# Monitor rollout
kubectl rollout status deployment/fastapi-app -n greenfield-prod
```

### Rollback

```bash
# Rollback deployment
kubectl rollout undo deployment/fastapi-app -n greenfield-prod

# Rollback to specific revision
kubectl rollout undo deployment/fastapi-app --to-revision=2 -n greenfield-prod
```

## Cost Optimization

1. Use spot/preemptible instances for non-critical workloads
2. Enable cluster autoscaling
3. Right-size resource requests and limits
4. Use PVC storage optimization
5. Implement pod disruption budgets
6. Schedule non-critical jobs during off-peak hours

## Next Steps

- Configure DNS and SSL/TLS certificates
- Set up CI/CD pipelines
- Implement additional security policies
- Configure backup automation
- Set up monitoring alerts
- Document runbooks for common operations
