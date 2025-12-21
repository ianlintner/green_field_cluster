# Kustomize Deployment Guide

Kustomize is the recommended deployment method for Greenfield Cluster. It provides declarative configuration management with environment-specific overlays, making it perfect for GitOps workflows.

## Overview

Kustomize allows you to customize Kubernetes manifests without modifying the original files. It uses a declarative approach with patches and overlays for environment-specific configurations.

### Why Kustomize?

- ✅ **Native Kubernetes**: Built into kubectl (v1.14+)
- ✅ **Declarative**: Define what you want, not how to get there
- ✅ **Composable**: Build complex configurations from simple pieces
- ✅ **GitOps-Ready**: Perfect for ArgoCD and Flux CD
- ✅ **No Templating**: Use actual Kubernetes YAML, not templates

## Project Structure

```
kustomize/
├── base/                          # Base configurations
│   ├── namespace/                 # Namespace definition
│   ├── redis/                     # Redis manifests
│   ├── postgres/                  # PostgreSQL manifests
│   ├── mysql/                     # MySQL manifests
│   ├── mongodb/                   # MongoDB manifests
│   ├── kafka/                     # Kafka manifests
│   ├── istio/                     # Istio service mesh
│   ├── cert-manager/              # Certificate management
│   ├── otel-collector/            # OpenTelemetry collector
│   ├── jaeger/                    # Jaeger tracing
│   ├── prometheus/                # Prometheus metrics
│   ├── grafana/                   # Grafana dashboards
│   ├── observability/             # SLOs and alerts
│   ├── fastapi-app/               # Example application
│   ├── sealed-secrets/            # Sealed secrets controller
│   ├── auth/                      # Authentication system
│   └── kustomization.yaml         # Base kustomization file
└── overlays/                      # Environment-specific configs
    ├── dev/                       # Development environment
    │   ├── kustomization.yaml
    │   └── patches/
    ├── staging/                   # Staging environment
    │   ├── kustomization.yaml
    │   └── patches/
    └── prod/                      # Production environment
        ├── kustomization.yaml
        └── patches/
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.24+)
- kubectl with Kustomize support (built-in)
- At least 8 CPU cores, 16GB RAM

### Deploy Base Configuration

Deploy all components with default settings:

```bash
kubectl apply -k kustomize/base/
```

### Deploy with Environment Overlay

Deploy with environment-specific configurations:

```bash
# Development
kubectl apply -k kustomize/overlays/dev/

# Staging
kubectl apply -k kustomize/overlays/staging/

# Production
kubectl apply -k kustomize/overlays/prod/
```

## Base Configuration

The `base/` directory contains the standard configuration for all components.

### Base Kustomization File

`kustomize/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield

resources:
  - namespace
  - redis
  - postgres
  - mysql
  - mongodb
  - kafka
  - istio
  - cert-manager
  - otel-collector
  - jaeger
  - prometheus
  - grafana
  - observability
  - fastapi-app
  - sealed-secrets
```

### Selecting Components

Comment out components you don't need:

```yaml
resources:
  - namespace
  - redis
  - postgres
  # - mysql        # Not using MySQL
  # - mongodb      # Not using MongoDB
  - kafka
  - istio
  - otel-collector
  - jaeger
  - prometheus
  - grafana
```

## Environment Overlays

Overlays customize the base configuration for specific environments.

### Development Overlay

**Characteristics:**
- Single replicas
- Minimal resources
- Local storage
- Relaxed limits

`kustomize/overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield

bases:
  - ../../base

replicas:
  - name: fastapi-app
    count: 1
  - name: redis-master
    count: 1
  - name: redis-replica
    count: 0

patches:
  - path: patches/resource-limits.yaml
  - path: patches/storage.yaml

configMapGenerator:
  - name: env-config
    literals:
      - ENVIRONMENT=development
      - LOG_LEVEL=debug
```

### Staging Overlay

**Characteristics:**
- Multiple replicas
- Medium resources
- Production-like setup
- Testing configuration

`kustomize/overlays/staging/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield-staging

bases:
  - ../../base

nameSuffix: -staging

replicas:
  - name: fastapi-app
    count: 2
  - name: redis-replica
    count: 1

patches:
  - path: patches/resource-limits.yaml
  - path: patches/ingress.yaml

configMapGenerator:
  - name: env-config
    literals:
      - ENVIRONMENT=staging
      - LOG_LEVEL=info
```

### Production Overlay

**Characteristics:**
- High availability
- Full resource allocation
- Multiple replicas
- Production-grade configuration

`kustomize/overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield

bases:
  - ../../base

replicas:
  - name: fastapi-app
    count: 5
  - name: redis-replica
    count: 2
  - name: postgres
    count: 3
  - name: mysql
    count: 3
  - name: mongodb
    count: 3

patches:
  - path: patches/resource-limits.yaml
  - path: patches/anti-affinity.yaml
  - path: patches/pdb.yaml
  - path: patches/ingress-tls.yaml

configMapGenerator:
  - name: env-config
    literals:
      - ENVIRONMENT=production
      - LOG_LEVEL=warning
```

## Customization Techniques

### Patching Resources

#### Strategic Merge Patch

Modify specific fields in resources:

`overlays/prod/patches/resource-limits.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-app
spec:
  template:
    spec:
      containers:
        - name: fastapi-app
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 4Gi
```

#### JSON Patch

Precise modifications using JSON Patch syntax:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

patches:
  - target:
      kind: Deployment
      name: fastapi-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 10
      - op: add
        path: /spec/template/metadata/annotations
        value:
          prometheus.io/scrape: "true"
```

### Replica Count

Scale deployments and statefulsets:

```yaml
replicas:
  - name: fastapi-app
    count: 5
  - name: redis-master
    count: 1
  - name: redis-replica
    count: 3
```

### Name Prefix/Suffix

Add prefixes or suffixes to resource names:

```yaml
namePrefix: prod-
nameSuffix: -v2

# Results in: prod-fastapi-app-v2
```

### Namespace

Override the default namespace:

```yaml
namespace: my-custom-namespace
```

### Labels and Annotations

Add common labels and annotations to all resources:

```yaml
commonLabels:
  environment: production
  team: platform
  managed-by: kustomize

commonAnnotations:
  contact: platform-team@example.com
  documentation: https://docs.example.com
```

### ConfigMap and Secret Generators

Generate ConfigMaps and Secrets from literals or files:

```yaml
configMapGenerator:
  - name: app-config
    literals:
      - DATABASE_HOST=postgres-service
      - REDIS_HOST=redis-service
    files:
      - application.conf

secretGenerator:
  - name: app-secrets
    literals:
      - API_KEY=changeme
    files:
      - tls.crt
      - tls.key
```

### Image Transformation

Override image tags:

```yaml
images:
  - name: fastapi-example
    newTag: v2.0.0
  - name: redis
    newName: redis/redis-stack
    newTag: latest
```

## Advanced Patterns

### Component-Based Organization

Use Kustomize components for optional features:

```yaml
# kustomize/components/monitoring/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

resources:
  - prometheus
  - grafana
```

```yaml
# overlays/prod/kustomization.yaml
components:
  - ../../components/monitoring
  - ../../components/security
```

### Multiple Bases

Combine multiple base configurations:

```yaml
bases:
  - ../../base
  - ../../../shared-infra
  - github.com/company/k8s-common?ref=v1.0
```

### Remote Resources

Reference resources from remote repositories:

```yaml
resources:
  - https://raw.githubusercontent.com/istio/istio/1.20.0/manifests/charts/base/crds/crd-all.gen.yaml
  - github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml
```

### Helm Chart Integration

Include Helm charts in Kustomize:

```yaml
helmCharts:
  - name: postgresql
    repo: https://charts.bitnami.com/bitnami
    version: 12.x.x
    releaseName: postgres
    namespace: greenfield
    valuesFile: values.yaml
```

## Validation and Testing

### Preview Changes

Generate output without applying:

```bash
# Build and preview
kubectl kustomize kustomize/overlays/prod/

# Save to file for review
kubectl kustomize kustomize/overlays/prod/ > output.yaml
```

### Dry Run

Test application without making changes:

```bash
# Client-side dry run
kubectl apply -k kustomize/overlays/prod/ --dry-run=client

# Server-side dry run (validates against API server)
kubectl apply -k kustomize/overlays/prod/ --dry-run=server
```

### Diff Changes

See what will change before applying:

```bash
kubectl diff -k kustomize/overlays/prod/
```

### Validate Syntax

Check YAML syntax and structure:

```bash
# Validate with kustomize
kustomize build kustomize/overlays/prod/ | kubectl apply --dry-run=client -f -

# Use kubeconform for validation
kustomize build kustomize/overlays/prod/ | kubeconform -strict -
```

## Deployment Workflows

### Manual Deployment

```bash
# Deploy to development
kubectl apply -k kustomize/overlays/dev/

# Wait for rollout
kubectl rollout status deployment -n greenfield

# Verify deployment
kubectl get pods -n greenfield
```

### GitOps with ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: greenfield-cluster
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yourusername/green_field_cluster
    targetRevision: main
    path: kustomize/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: greenfield
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### GitOps with Flux CD

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: greenfield-cluster
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/yourusername/green_field_cluster
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: greenfield-cluster
  namespace: flux-system
spec:
  interval: 10m
  path: ./kustomize/overlays/prod
  prune: true
  sourceRef:
    kind: GitRepository
    name: greenfield-cluster
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: fastapi-app
      namespace: greenfield
```

## Managing Updates

### Update Deployment

```bash
# Pull latest changes
git pull origin main

# Preview changes
kubectl diff -k kustomize/overlays/prod/

# Apply updates
kubectl apply -k kustomize/overlays/prod/

# Watch rollout
kubectl rollout status deployment/fastapi-app -n greenfield
```

### Rollback Changes

```bash
# Revert Git commit
git revert HEAD
kubectl apply -k kustomize/overlays/prod/

# Or checkout previous commit
git checkout <previous-commit>
kubectl apply -k kustomize/overlays/prod/
git checkout main
```

## Best Practices

### Organization

1. **Keep base/ generic**: No environment-specific configuration
2. **Use overlays for environment differences**: dev, staging, prod
3. **Component per service**: Separate directory for each component
4. **Consistent naming**: Follow naming conventions across all resources

### Configuration Management

1. **Use ConfigMaps for configuration**: Not hardcoded in deployments
2. **Generate secrets with kustomize**: Use secretGenerator
3. **Version control everything**: All configurations in Git
4. **Document patches**: Comment why patches are needed

### Resource Management

1. **Always set resource requests/limits**: In production overlays
2. **Use pod disruption budgets**: For high availability
3. **Configure anti-affinity**: Spread pods across nodes
4. **Set appropriate replica counts**: Based on environment

### Security

1. **Never commit secrets**: Use Sealed Secrets or external secret managers
2. **Use RBAC**: Define appropriate roles and bindings
3. **Enable security contexts**: Run as non-root when possible
4. **Regular updates**: Keep base images and dependencies updated

## Troubleshooting

### Common Issues

**Error: no matches for kind "X" in version "Y"**

Solution: Ensure CRDs are installed first:
```bash
kubectl apply -k kustomize/base/cert-manager/crds/
kubectl apply -k kustomize/base/istio/crds/
```

**Error: namespace not found**

Solution: Apply namespace first or use `--create-namespace`:
```bash
kubectl create namespace greenfield
kubectl apply -k kustomize/overlays/prod/
```

**Patch doesn't apply**

Solution: Verify patch target and structure:
```bash
# Generate output to debug
kubectl kustomize kustomize/overlays/prod/ > debug.yaml
```

**Resource already exists**

Solution: Use declarative apply with `--server-side`:
```bash
kubectl apply -k kustomize/overlays/prod/ --server-side
```

## Migration from Helm

If migrating from Helm to Kustomize:

1. **Export Helm values as YAML**:
   ```bash
   helm template greenfield helm/greenfield-cluster > base-manifests.yaml
   ```

2. **Organize into base structure**:
   Split manifests by component into `kustomize/base/`

3. **Create kustomization.yaml**:
   Reference all component directories

4. **Create overlays**:
   Extract environment-specific values into overlay patches

5. **Test thoroughly**:
   Deploy to dev environment first

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Kustomize Guide](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)
- [Kustomize Best Practices](https://kubectl.docs.kubernetes.io/guides/config_management/introduction/)

## Next Steps

- [Deployment Methods Overview](methods.md)
- [Helm Deployment Guide](helm.md)
- [Cloud Provider Deployment](aws-eks.md)
- [Security Configuration](../security/overview.md)
