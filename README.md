# Greenfield Cluster

A production-ready Kubernetes cluster setup for greenfield projects and startups with comprehensive infrastructure, observability, and security features.

## ⚠️ SECURITY WARNING

**This repository contains DEFAULT PASSWORDS for demonstration purposes only.**

**DO NOT use these passwords in production!** All default passwords must be changed before deploying to any non-development environment.

See [Security Configuration Guide](docs/SECURITY.md) for instructions on properly configuring secrets.

## 📚 Documentation

**[View Full Documentation →](https://ianlintner.github.io/green_field_cluster/)**

Comprehensive documentation with:
- Getting started guides
- Deployment tutorials
- Architecture diagrams
- Component details
- Security best practices

## 🚀 Quick Start

### As a Template (Recommended)

Create your own project from this template:

```bash
gh repo create my-project --template ianlintner/green_field_cluster --private --clone
cd my-project
```

### Clone Directly

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
- ✅ **Istio** - Service mesh with SSL/TLS ingress (internal & external gateways)

### Observability Stack
- ✅ **OpenTelemetry Collector** - Centralized telemetry
- ✅ **Jaeger** - Distributed tracing
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Dashboards and visualization

### Security & SSL/TLS
- ✅ **cert-manager** - Automated SSL/TLS certificate management
- ✅ **Let's Encrypt Integration** - Staging and production issuers
- ✅ **SSL Ingress** - External gateway with TLS termination
- ✅ **Sealed Secrets** - Encrypted Kubernetes secrets
- ✅ **Modular Authentication** - Drop-in SAML, OAuth2, OIDC support
  - Azure AD, Google, GitHub, Okta integration
  - oauth2-proxy with Istio ext_authz
  - Optional Keycloak IdP broker
  - Group-based authorization policies

### DevOps & Automation
- ✅ **GitHub Actions CI** - Automated manifest validation
- ✅ **Quality Gates** - Kustomize, Helm, YAML linting
- ✅ **Kind Cluster Testing** - Real K8s cluster testing in CI
- ✅ **Security Scanning** - Trivy vulnerability checks
- ✅ **Auto-deployed Docs** - MkDocs on GitHub Pages
- ✅ **Copilot Integration** - AI-assisted customization

### Example Application
- ✅ **FastAPI App** - Fully instrumented with OTel and Prometheus metrics

### Observability Stack
- ✅ **OpenTelemetry Collector** - Centralized telemetry
- ✅ **Jaeger** - Distributed tracing
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Dashboards and visualization

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
│   │   ├── istio/         # Istio service mesh with SSL/TLS
│   │   ├── cert-manager/  # Certificate management
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
├── platform/
│   └── auth/              # Modular authentication
│       ├── base/          # oauth2-proxy, Keycloak, policies
│       └── overlays/      # Provider configs (Azure AD, Google, etc.)
├── helm/
│   └── greenfield-cluster/ # Helm chart
├── apps/
│   ├── fastapi-example/   # Example FastAPI application
│   └── templates/         # App protection templates
├── scripts/               # Automation scripts
│   ├── auth-install.sh
│   ├── auth-protect.sh
│   └── auth-doctor.sh
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

This project includes comprehensive security features:

### Secrets Management
- **Sealed Secrets** for encrypting Kubernetes secrets before storing them in Git
- See [kustomize/base/sealed-secrets/README.md](kustomize/base/sealed-secrets/README.md) for setup

### Authentication & Authorization
- **Modular Auth System** - Drop-in authentication for any HTTP application
- **Multiple Providers** - Azure AD, Google, GitHub, Okta SAML, Keycloak
- **Zero App Changes** - Authentication enforced at Istio ingress gateway
- **Fine-Grained Access** - Group-based and domain-based authorization policies

#### Quick Start with Authentication

```bash
# Install authentication with Azure AD
make auth.install PROVIDER=azuread DOMAIN=example.com

# Protect an application
make auth.protect APP=myapp HOST=myapp.example.com POLICY=group:developers

# Verify setup
make auth.doctor
```

See [platform/auth/README.md](platform/auth/base/README.md) for detailed authentication documentation.

## 🧪 Testing

### Local Kind Cluster Testing

Test manifests on a local Kubernetes cluster:

```bash
# Run automated test on Kind cluster
./scripts/test-kind-cluster.sh

# Or use Make
make test-kind-cluster

# Create/delete Kind cluster manually
make kind-create
make kind-delete
```

See [docs/development/testing.md](docs-mkdocs/docs/development/testing.md) for detailed testing documentation.

### Port Forwarding

```bash
# Port forward to FastAPI app
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/redis
curl http://localhost:8000/postgres
```

## 🌐 Cloud Providers

Works with all major cloud providers. **Ready-to-use infrastructure examples** available in the [`infrastructure/`](infrastructure/) directory:

- **Amazon EKS** - Terraform with ARM Graviton support ([guide](infrastructure/aws/))
- **Google GKE** - Terraform with ARM Tau T2A support ([guide](infrastructure/gcp/))
- **Azure AKS** - Terraform with ARM Ampere Altra support ([guide](infrastructure/azure/))
- **DigitalOcean Kubernetes** - Terraform configuration ([guide](infrastructure/digitalocean/))
- **On-premises clusters** - kubeadm, k3s, RKE2, OpenStack Magnum ([guide](infrastructure/on-premises/))

See the [Infrastructure README](infrastructure/README.md) for quick cluster setup instructions.

## 📊 Monitoring

- **Grafana**: `kubectl port-forward -n greenfield svc/grafana 3000:3000`
- **Prometheus**: `kubectl port-forward -n greenfield svc/prometheus 9090:9090`
- **Jaeger**: `kubectl port-forward -n greenfield svc/jaeger-query 16686:16686`

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - see LICENSE file for details
