# Quick Start Guide

Get the Greenfield Cluster running in minutes!

## Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl installed
- 8 CPU cores, 16GB RAM minimum

## 5-Minute Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/ianlintner/green_field_cluster.git
cd green_field_cluster
```

### Step 2: Install Prerequisites

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y
cd ..

# Install Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
```

### Step 3: Deploy the Cluster

```bash
# Deploy everything
kubectl apply -k kustomize/base/

# Or use development overlay
kubectl apply -k kustomize/overlays/dev/
```

### Step 4: Wait for Pods

```bash
# Watch pods come up
kubectl get pods -n greenfield -w

# Or wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n greenfield --timeout=600s
```

### Step 5: Access Services

```bash
# Port forward to FastAPI app
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000 &

# Test the application
curl http://localhost:8000/health
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
```

### Step 6: Access Observability Tools

```bash
# Grafana (admin/admin123)
kubectl port-forward -n greenfield svc/grafana 3000:3000 &
open http://localhost:3000

# Jaeger Tracing UI
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686 &
open http://localhost:16686

# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090 &
open http://localhost:9090
```

## Testing the Deployment

```bash
# Test all database connections
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
curl http://localhost:8000/mysql
curl http://localhost:8000/mongodb

# Test Kafka
curl -X POST http://localhost:8000/kafka

# Check metrics
curl http://localhost:8000/metrics
```

## Local Development (Minikube)

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# Deploy
kubectl apply -k kustomize/overlays/dev/

# Access services
minikube service fastapi-app -n greenfield-dev
```

## Helm Installation

```bash
# Install with Helm
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace

# Check status
helm status greenfield
```

## Build Custom FastAPI Image

If you want to build and use your own image:

```bash
# Build the image
cd apps/fastapi-example
docker build -t fastapi-example:latest .

# Load into Minikube (for local testing)
minikube image load fastapi-example:latest

# Or push to your registry
docker tag fastapi-example:latest your-registry/fastapi-example:latest
docker push your-registry/fastapi-example:latest
```

## Troubleshooting

### Pods Stuck in Pending

```bash
# Check events
kubectl get events -n greenfield --sort-by='.lastTimestamp'

# Check if storage class exists
kubectl get storageclass

# For Minikube, enable storage provisioner
minikube addons enable storage-provisioner
```

### ImagePullBackOff for FastAPI

The default deployment uses `imagePullPolicy: IfNotPresent` and expects the image to be built locally or available in your registry.

```bash
# Option 1: Build and load into Minikube
cd apps/fastapi-example
docker build -t fastapi-example:latest .
minikube image load fastapi-example:latest

# Option 2: Use a pre-built image
# Update kustomize/base/fastapi-app/deployment.yaml
# Change image to a public registry or your own
```

### Database Connection Errors

Wait for databases to be fully initialized:

```bash
# Check database pod logs
kubectl logs -n greenfield postgres-0
kubectl logs -n greenfield mysql-0
kubectl logs -n greenfield mongodb-0
kubectl logs -n greenfield redis-master-0

# Restart FastAPI pods after databases are ready
kubectl rollout restart deployment/fastapi-app -n greenfield
```

## What's Included?

- ✅ Redis (1 master + 2 replicas)
- ✅ PostgreSQL (3 instances)
- ✅ MySQL (3 instances)
- ✅ MongoDB (3 instances)
- ✅ Kafka + Zookeeper (3 instances each)
- ✅ OpenTelemetry Collector (2 replicas)
- ✅ Jaeger (distributed tracing)
- ✅ Prometheus (metrics)
- ✅ Grafana (dashboards)
- ✅ FastAPI example app (2 replicas)
- ✅ Istio service mesh (installed separately)
- ✅ Sealed Secrets (installed separately)

## Next Steps

1. **Customize Configuration**: Edit `kustomize/overlays/dev/kustomization.yaml`
2. **Add Your Application**: Use FastAPI app as a template
3. **Configure Monitoring**: Import Grafana dashboards
4. **Set Up Ingress**: Configure Istio ingress for external access
5. **Implement Secrets**: Use sealed-secrets for sensitive data
6. **CI/CD Integration**: Set up automated deployments

## Clean Up

```bash
# Delete everything
kubectl delete -k kustomize/base/

# Or delete namespace
kubectl delete namespace greenfield

# Stop port forwards
killall kubectl
```

## Get Help

- 📖 [Full Documentation](docs/README.md)
- 🏗️ [Architecture Guide](docs/ARCHITECTURE.md)
- 🚀 [Deployment Guide](docs/DEPLOYMENT.md)
- 🐛 [GitHub Issues](https://github.com/ianlintner/green_field_cluster/issues)

## Cloud Provider Quick Start

### AWS EKS

```bash
eksctl create cluster --name greenfield --region us-west-2
kubectl apply -k kustomize/overlays/prod/
```

### GCP GKE

```bash
gcloud container clusters create greenfield --zone us-central1-a
kubectl apply -k kustomize/overlays/prod/
```

### Azure AKS

```bash
az aks create --resource-group greenfield-rg --name greenfield
az aks get-credentials --resource-group greenfield-rg --name greenfield
kubectl apply -k kustomize/overlays/prod/
```

Happy Coding! 🚀
