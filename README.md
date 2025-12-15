# Greenfield Cluster

A production-ready Kubernetes cluster setup for greenfield projects and startups with comprehensive infrastructure, observability, and security features.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/ianlintner/green_field_cluster.git
cd green_field_cluster

# Deploy using Kustomize
kubectl apply -k kustomize/base/

# Or deploy using Helm
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## 📋 Features

### Infrastructure Components
- ✅ **Redis** - Master-replica setup with persistence
- ✅ **PostgreSQL** - Multi-instance cluster for HA
- ✅ **MySQL** - Multi-instance cluster with replication
- ✅ **MongoDB** - Replica set configuration
- ✅ **Kafka** - Distributed messaging with Zookeeper
- ✅ **Istio** - Service mesh for traffic management

### Observability Stack
- ✅ **OpenTelemetry Collector** - Centralized telemetry
- ✅ **Jaeger** - Distributed tracing
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Dashboards and visualization

### Security
- ✅ **Sealed Secrets** - Encrypted Kubernetes secrets

### Example Application
- ✅ **FastAPI App** - Fully instrumented with OTel and Prometheus metrics

## 📖 Documentation

For detailed documentation, see [docs/README.md](docs/README.md)

## 🏗️ Project Structure

```
.
├── kustomize/
│   ├── base/              # Base Kubernetes manifests
│   │   ├── namespace/
│   │   ├── redis/
│   │   ├── postgres/
│   │   ├── mysql/
│   │   ├── mongodb/
│   │   ├── kafka/
│   │   ├── istio/
│   │   ├── otel-collector/
│   │   ├── jaeger/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   ├── sealed-secrets/
│   │   └── fastapi-app/
│   └── overlays/          # Environment-specific configs
│       ├── dev/
│       ├── staging/
│       └── prod/
├── helm/
│   └── greenfield-cluster/ # Helm chart
├── apps/
│   └── fastapi-example/   # Example FastAPI application
└── docs/                  # Documentation

```

## 🔧 Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl configured
- Helm 3.0+ (for Helm deployment)
- Kustomize v4.5.7+ (for Kustomize deployment)

## 📦 Installation

### Using Kustomize

```bash
# Deploy to development
kubectl apply -k kustomize/overlays/dev/

# Deploy to production
kubectl apply -k kustomize/overlays/prod/
```

### Using Helm

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values custom-values.yaml
```

## 🔐 Security

This project uses **Sealed Secrets** for encrypting Kubernetes secrets before storing them in Git. See [kustomize/base/sealed-secrets/README.md](kustomize/base/sealed-secrets/README.md) for setup instructions.

## 🧪 Testing

```bash
# Port forward to FastAPI app
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
```

## 🌐 Cloud Providers

Works with all major cloud providers:
- Amazon EKS
- Google GKE
- Azure AKS
- DigitalOcean Kubernetes
- On-premises clusters

## 📊 Monitoring

- **Grafana**: `kubectl port-forward -n greenfield svc/grafana 3000:3000`
- **Prometheus**: `kubectl port-forward -n greenfield svc/prometheus 9090:9090`
- **Jaeger**: `kubectl port-forward -n greenfield svc/jaeger-query 16686:16686`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details
