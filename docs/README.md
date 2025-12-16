# Greenfield Cluster

A production-ready Kubernetes cluster setup for greenfield projects with comprehensive infrastructure components, observability stack, and example applications.

## Overview

This repository provides a complete MVP Kubernetes cluster that can be deployed to any major cloud provider (AWS, GCP, Azure, etc.) using either Kustomize or Helm charts.

## Features

### Infrastructure Components

- **Redis**: Master-replica setup with persistence
- **PostgreSQL**: Multi-instance cluster for high availability
- **MySQL**: Multi-instance cluster with replication
- **MongoDB**: Replica set configuration
- **Kafka**: Distributed message broker with Zookeeper
- **Istio**: Service mesh for advanced traffic management

### Observability Stack

- **OpenTelemetry Collector**: Centralized telemetry collection
- **Jaeger**: Distributed tracing backend
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards

### Security

- **Sealed Secrets**: Encrypted Kubernetes secrets management using Bitnami's sealed-secrets

### Example Application

- **FastAPI Application**: Fully instrumented example app with:
  - OpenTelemetry tracing integration
  - Prometheus metrics endpoint
  - Connections to all infrastructure components
  - Health check endpoints

## Deployment Methods

### Method 1: Kustomize (Recommended)

#### Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl installed and configured
- kustomize v4.5.7+

#### Deploy Base Configuration

```bash
# Deploy all components
kubectl apply -k kustomize/base/

# Verify deployment
kubectl get pods -n greenfield
```

#### Deploy with Environment-Specific Overlays

```bash
# Development environment
kubectl apply -k kustomize/overlays/dev/

# Staging environment
kubectl apply -k kustomize/overlays/staging/

# Production environment
kubectl apply -k kustomize/overlays/prod/
```

### Method 2: Helm

#### Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.0+

#### Install with Helm

```bash
# Add the repository (if published)
# helm repo add greenfield https://charts.example.com

# Install the chart
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace

# Custom values
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values custom-values.yaml
```

#### Upgrade

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values custom-values.yaml
```

## Prerequisites Installation

### 1. Install Istio

```bash
# Using Istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y

# Or using Helm
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system --wait
```

### 2. Install Sealed Secrets Controller

```bash
# Using Helm
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system

# Or using kubectl
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml

# Install kubeseal CLI
# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# macOS
brew install kubeseal
```

## Building the FastAPI Example Application

```bash
cd apps/fastapi-example

# Build Docker image
docker build -t fastapi-example:latest .

# Push to your registry (replace with your registry)
docker tag fastapi-example:latest your-registry/fastapi-example:latest
docker push your-registry/fastapi-example:latest

# Update the image reference in kustomize/base/fastapi-app/deployment.yaml
# or in helm/greenfield-cluster/values.yaml
```

## Accessing Services

### Port Forwarding (Development)

```bash
# FastAPI Application
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000
# Access at http://localhost:8000

# Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000
# Access at http://localhost:3000 (admin/admin123)

# Jaeger UI
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686
# Access at http://localhost:16686

# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Access at http://localhost:9090
```

### Using Istio Ingress Gateway (Production)

After installing Istio, configure ingress resources for external access.

## Configuration

### Environment Variables

The FastAPI application can be configured using environment variables. See `kustomize/base/fastapi-app/configmap.yaml` for available options.

### Secrets Management

1. Create your secrets:
```bash
kubectl create secret generic postgres-secret \
  --from-literal=password=your-secure-password \
  --dry-run=client -o yaml > secret.yaml
```

2. Seal the secret:
```bash
kubeseal -f secret.yaml -w sealed-secret.yaml \
  --controller-namespace=kube-system
```

3. Apply the sealed secret:
```bash
kubectl apply -f sealed-secret.yaml -n greenfield
```

### Customization

#### Kustomize

Edit the overlay files in `kustomize/overlays/{dev,staging,prod}/` to customize:
- Replica counts
- Resource limits
- Storage sizes
- Environment-specific configurations

#### Helm

Create a custom values file:

```yaml
# custom-values.yaml
namespace: my-namespace

redis:
  replica:
    replicas: 3

postgres:
  replicas: 5
  persistence:
    size: 20Gi

fastapi:
  replicas: 5
  image:
    repository: my-registry/fastapi-example
    tag: v1.2.3
```

Apply with:
```bash
helm install greenfield helm/greenfield-cluster -f custom-values.yaml
```

## Monitoring and Observability

### Metrics

- Prometheus scrapes metrics from all components
- Access Prometheus UI to query metrics
- Grafana provides pre-configured dashboards

### Tracing

- OpenTelemetry Collector receives traces from applications
- Jaeger stores and visualizes distributed traces
- Access Jaeger UI to explore traces

### Logs

- Application logs are written to stdout/stderr
- Use `kubectl logs` to view container logs
- Consider integrating with ELK stack or Loki for centralized logging

## Testing the Deployment

```bash
# Check all pods are running
kubectl get pods -n greenfield

# Test the FastAPI application
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000

# In another terminal, test endpoints
curl http://localhost:8000/
curl http://localhost:8000/health
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
curl http://localhost:8000/mysql
curl http://localhost:8000/mongodb
curl -X POST http://localhost:8000/kafka
```

## Cloud Provider Specific Notes

### AWS EKS

```bash
# Create EKS cluster
eksctl create cluster --name greenfield --region us-west-2

# Deploy
kubectl apply -k kustomize/base/
```

### GCP GKE

```bash
# Create GKE cluster
gcloud container clusters create greenfield \
  --zone us-central1-a \
  --num-nodes 3

# Deploy
kubectl apply -k kustomize/base/
```

### Azure AKS

```bash
# Create AKS cluster
az aks create \
  --resource-group greenfield-rg \
  --name greenfield \
  --node-count 3

# Get credentials
az aks get-credentials --resource-group greenfield-rg --name greenfield

# Deploy
kubectl apply -k kustomize/base/
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Istio Service Mesh                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Ingress    │  │   FastAPI    │  │  Observability│ │
│  │   Gateway    │─▶│     App      │─▶│     Stack     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
    ┌────▼────┐      ┌─────▼─────┐     ┌─────▼─────┐
    │ Databases│      │ Messaging │     │Observability│
    ├─────────┤      ├───────────┤     ├───────────┤
    │ Redis   │      │  Kafka    │     │Prometheus │
    │ Postgres│      │ Zookeeper │     │  Jaeger   │
    │ MySQL   │      └───────────┘     │  Grafana  │
    │ MongoDB │                        │   OTel    │
    └─────────┘                        └───────────┘
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n greenfield

# Describe pod for events
kubectl describe pod <pod-name> -n greenfield

# Check logs
kubectl logs <pod-name> -n greenfield
```

### PersistentVolumeClaims pending

```bash
# Check PVC status
kubectl get pvc -n greenfield

# Check storage class
kubectl get storageclass

# Ensure your cluster has a default storage class or specify one
```

### Database connection errors

- Ensure databases are fully started before the FastAPI app
- Check service names and ports in configuration
- Verify secrets are properly created

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please open an issue on GitHub.
