# Quick Start Guide

Get your Greenfield Cluster running in **5 minutes**!

## Prerequisites

Before you begin, ensure you have:

- ✅ Kubernetes cluster (v1.24+) running
- ✅ `kubectl` configured and connected to your cluster
- ✅ `kustomize` v4.5.7+ (or use `kubectl apply -k`)
- ✅ Minimum 8 CPU cores, 16GB RAM in your cluster

## Installation Steps

### Step 1: Clone or Create from Template

=== "Create from Template (Recommended)"

    Create a new repository from the template:
    
    ```bash
    gh repo create my-project \
      --template ianlintner/green_field_cluster \
      --private \
      --clone
    
    cd my-project
    ```

=== "Clone Directly"

    ```bash
    git clone https://github.com/ianlintner/green_field_cluster.git
    cd green_field_cluster
    ```

### Step 2: Install Prerequisites

Install Istio and Sealed Secrets:

```bash
# Install Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=default -y
cd ..

# Install Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
```

### Step 3: Deploy the Cluster

=== "Kustomize (Recommended)"

    Deploy all components:
    
    ```bash
    kubectl apply -k kustomize/base/
    ```
    
    Or use environment-specific overlay:
    
    ```bash
    # Development
    kubectl apply -k kustomize/overlays/dev/
    
    # Production
    kubectl apply -k kustomize/overlays/prod/
    ```

=== "Helm"

    ```bash
    helm install greenfield helm/greenfield-cluster \
      --namespace greenfield \
      --create-namespace
    ```

### Step 4: Wait for Pods

Watch pods come up:

```bash
kubectl get pods -n greenfield -w
```

Or wait for all pods to be ready:

```bash
kubectl wait --for=condition=ready pod \
  --all -n greenfield \
  --timeout=600s
```

### Step 5: Verify Deployment

Check that all components are running:

```bash
kubectl get all -n greenfield
```

Expected output:
```
NAME                                READY   STATUS    RESTARTS   AGE
pod/fastapi-app-xxx                 2/2     Running   0          2m
pod/grafana-xxx                     1/1     Running   0          2m
pod/jaeger-xxx                      1/1     Running   0          2m
pod/kafka-0                         1/1     Running   0          2m
pod/mongodb-0                       1/1     Running   0          2m
pod/mysql-0                         1/1     Running   0          2m
pod/otel-collector-xxx              1/1     Running   0          2m
pod/postgres-0                      1/1     Running   0          2m
pod/prometheus-xxx                  1/1     Running   0          2m
pod/redis-master-0                  1/1     Running   0          2m
pod/redis-replica-0                 1/1     Running   0          2m
pod/zookeeper-0                     1/1     Running   0          2m
```

## Accessing Services

### Port Forward to Services

```bash
# FastAPI Application
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000 &

# Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000 &

# Jaeger UI
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686 &

# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090 &
```

### Test the Application

```bash
# Health check
curl http://localhost:8000/health

# Test Redis
curl http://localhost:8000/redis

# Test PostgreSQL
curl http://localhost:8000/postgres

# Test MySQL
curl http://localhost:8000/mysql

# Test MongoDB
curl http://localhost:8000/mongodb

# Test Kafka
curl -X POST http://localhost:8000/kafka

# View metrics
curl http://localhost:8000/metrics
```

### Access Observability Tools

Open in your browser:

- **Grafana**: http://localhost:3000 (admin/admin123)
- **Jaeger**: http://localhost:16686
- **Prometheus**: http://localhost:9090
- **FastAPI Docs**: http://localhost:8000/docs

## Quick Customization

### Remove Unused Components

If you don't need certain databases:

```bash
# Edit kustomize/base/kustomization.yaml
# Comment out components you don't need:

resources:
  - namespace
  - redis
  - postgres
  # - mysql        # Not needed
  # - mongodb      # Not needed
  - kafka
  - otel-collector
  - jaeger
  - prometheus
  - grafana
  - fastapi-app
```

### Scale Services

Edit `kustomize/overlays/prod/kustomization.yaml`:

```yaml
replicas:
  - name: fastapi-app
    count: 5  # Scale to 5 replicas
```

Apply changes:

```bash
kubectl apply -k kustomize/overlays/prod/
```

## Building the FastAPI Image

The FastAPI example requires building a Docker image:

```bash
cd apps/fastapi-example

# Build image
docker build -t fastapi-example:latest .

# For Minikube
minikube image load fastapi-example:latest

# For cloud deployments, push to your registry
docker tag fastapi-example:latest your-registry/fastapi-example:latest
docker push your-registry/fastapi-example:latest
```

Update the image in `kustomize/base/fastapi-app/deployment.yaml`:

```yaml
image: your-registry/fastapi-example:latest
```

## Next Steps

1. ✅ **Configure Secrets**: [Security Guide](../security/overview.md)
2. ✅ **Add Your Application**: [Template Usage](template-usage.md)
3. ✅ **Set Up Ingress**: [Deployment Guide](../deployment/methods.md)
4. ✅ **Configure Monitoring**: [Observability](../components/otel.md)
5. ✅ **Deploy to Cloud**: [Cloud Providers](../deployment/aws-eks.md)

## Troubleshooting

### Pods Stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n greenfield
```

Ensure storage class exists:
```bash
kubectl get storageclass
```

For Minikube:
```bash
minikube addons enable storage-provisioner
```

### ImagePullBackOff for FastAPI

Build and load the image:
```bash
cd apps/fastapi-example
docker build -t fastapi-example:latest .
minikube image load fastapi-example:latest  # For Minikube
```

### Database Connection Errors

Wait for databases to fully initialize:
```bash
kubectl logs -n greenfield postgres-0
kubectl logs -n greenfield mysql-0
kubectl logs -n greenfield mongodb-0
```

Restart the FastAPI app after databases are ready:
```bash
kubectl rollout restart deployment/fastapi-app -n greenfield
```

## Clean Up

Remove everything:

```bash
# Delete all resources
kubectl delete -k kustomize/base/

# Or delete namespace
kubectl delete namespace greenfield
```

## Using the Makefile

For convenience, use the provided Makefile:

```bash
# Validate manifests
make validate

# Build configurations
make build-base
make build-prod

# Deploy
make deploy-dev
make deploy-prod

# Test connectivity
make test

# Port forward all services
make port-forward

# Clean up
make clean-dev
```

## Success!

You now have a complete Kubernetes cluster with:

- ✅ Multiple databases (Redis, PostgreSQL, MySQL, MongoDB)
- ✅ Message broker (Kafka)
- ✅ Service mesh (Istio)
- ✅ Full observability stack (OTel, Jaeger, Prometheus, Grafana)
- ✅ Example application

**Ready to customize?** Check out the [Template Usage Guide](template-usage.md)!
