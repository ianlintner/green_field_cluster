# Helm Deployment Guide

Helm provides a simple, template-based approach to deploying Greenfield Cluster. It's ideal for quick deployments and parameter-driven configuration management.

## Overview

Helm is the package manager for Kubernetes, allowing you to define, install, and upgrade Kubernetes applications using charts.

### Why Helm?

- ✅ **Simple Configuration**: Value-based parameter override
- ✅ **One Command Deployment**: Install everything at once
- ✅ **Release Management**: Built-in versioning and rollback
- ✅ **Templating**: Reusable chart templates
- ✅ **Package Distribution**: Easy sharing and distribution

## Prerequisites

- Kubernetes cluster (v1.24+)
- Helm 3.0+ installed
- kubectl configured
- At least 8 CPU cores, 16GB RAM

### Installing Helm

```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows
choco install kubernetes-helm

# Verify installation
helm version
```

## Quick Start

### Basic Installation

Install Greenfield Cluster with default values:

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace
```

### Installation with Custom Values

Create a custom values file:

```yaml
# my-values.yaml
redis:
  replicas: 2
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"

postgres:
  replicas: 3
  storage:
    size: "50Gi"

fastapi:
  replicas: 5
  image:
    tag: "v2.0.0"
```

Install with custom values:

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values my-values.yaml
```

### Installation with Inline Values

Override specific values inline:

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --set redis.replicas=3 \
  --set postgres.storage.size=100Gi \
  --set fastapi.image.tag=v2.0.0
```

## Chart Structure

```
helm/greenfield-cluster/
├── Chart.yaml                  # Chart metadata
├── values.yaml                 # Default values
├── values-dev.yaml             # Development values
├── values-staging.yaml         # Staging values
├── values-prod.yaml            # Production values
├── templates/                  # Template files
│   ├── NOTES.txt              # Post-install notes
│   ├── _helpers.tpl           # Template helpers
│   ├── namespace.yaml
│   ├── redis/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── postgres/
│   ├── mysql/
│   ├── mongodb/
│   ├── kafka/
│   ├── istio/
│   ├── otel-collector/
│   ├── jaeger/
│   ├── prometheus/
│   ├── grafana/
│   └── fastapi-app/
└── charts/                     # Subchart dependencies
```

## Configuration

### Default Values

The `values.yaml` file contains all configurable parameters:

```yaml
# Global settings
global:
  namespace: greenfield
  imageRegistry: docker.io
  storageClass: standard

# Component enablement
components:
  redis: true
  postgres: true
  mysql: true
  mongodb: true
  kafka: true
  istio: true
  otel: true
  jaeger: true
  prometheus: true
  grafana: true
  fastapi: true

# Redis configuration
redis:
  enabled: true
  replicas: 1
  image:
    repository: redis
    tag: "7-alpine"
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  persistence:
    enabled: true
    size: "10Gi"

# PostgreSQL configuration
postgres:
  enabled: true
  replicas: 1
  image:
    repository: postgres
    tag: "15-alpine"
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
  storage:
    size: "20Gi"
  database: "myapp"
  username: "appuser"

# FastAPI application
fastapi:
  enabled: true
  replicas: 2
  image:
    repository: fastapi-example
    tag: "latest"
    pullPolicy: IfNotPresent
  service:
    type: ClusterIP
    port: 8000
  ingress:
    enabled: false
    host: "api.example.com"
    tls:
      enabled: false
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
```

### Environment-Specific Values

#### Development Values

`values-dev.yaml`:

```yaml
# Minimal resources for development
redis:
  replicas: 1
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "250m"

postgres:
  replicas: 1
  storage:
    size: "10Gi"

fastapi:
  replicas: 1
  ingress:
    enabled: false
```

#### Staging Values

`values-staging.yaml`:

```yaml
# Production-like configuration
redis:
  replicas: 2
  resources:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"

postgres:
  replicas: 2
  storage:
    size: "50Gi"

fastapi:
  replicas: 3
  ingress:
    enabled: true
    host: "staging-api.example.com"
    tls:
      enabled: true
```

#### Production Values

`values-prod.yaml`:

```yaml
# High availability configuration
redis:
  replicas: 3
  resources:
    requests:
      memory: "1Gi"
      cpu: "1000m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
  persistence:
    size: "50Gi"

postgres:
  replicas: 3
  storage:
    size: "100Gi"
  backup:
    enabled: true

mysql:
  replicas: 3
  storage:
    size: "100Gi"

mongodb:
  replicas: 3
  storage:
    size: "100Gi"

kafka:
  replicas: 3

fastapi:
  replicas: 5
  autoscaling:
    enabled: true
    minReplicas: 5
    maxReplicas: 20
    targetCPUUtilizationPercentage: 70
  ingress:
    enabled: true
    host: "api.example.com"
    tls:
      enabled: true
      secretName: "api-tls"
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
```

## Deployment Scenarios

### Development Environment

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield-dev \
  --create-namespace \
  --values helm/greenfield-cluster/values-dev.yaml
```

### Staging Environment

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield-staging \
  --create-namespace \
  --values helm/greenfield-cluster/values-staging.yaml
```

### Production Environment

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values helm/greenfield-cluster/values-prod.yaml
```

### Custom Configuration

Combine multiple values files:

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values helm/greenfield-cluster/values-prod.yaml \
  --values my-custom-values.yaml
```

## Component Selection

### Enable/Disable Components

Disable components you don't need:

```yaml
# my-values.yaml
components:
  redis: true
  postgres: true
  mysql: false      # Disable MySQL
  mongodb: false    # Disable MongoDB
  kafka: true
  istio: true
  otel: true
  jaeger: true
  prometheus: true
  grafana: true
  fastapi: true
```

Or use inline flags:

```bash
helm install greenfield helm/greenfield-cluster \
  --set mysql.enabled=false \
  --set mongodb.enabled=false
```

## Managing Releases

### List Releases

```bash
# List all releases in all namespaces
helm list --all-namespaces

# List releases in specific namespace
helm list -n greenfield
```

### Get Release Status

```bash
helm status greenfield -n greenfield
```

### Get Release Values

```bash
# Show user-supplied values
helm get values greenfield -n greenfield

# Show all values (including defaults)
helm get values greenfield -n greenfield --all
```

### Get Release Manifest

```bash
helm get manifest greenfield -n greenfield
```

### Release History

```bash
helm history greenfield -n greenfield
```

## Upgrading Releases

### Basic Upgrade

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values my-values.yaml
```

### Upgrade with New Values

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --reuse-values \
  --set fastapi.replicas=10
```

### Force Upgrade

Force recreation of resources:

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --force
```

### Atomic Upgrade

Rollback on failure:

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --atomic \
  --timeout 10m
```

### Wait for Rollout

Wait for all pods to be ready:

```bash
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --wait \
  --timeout 10m
```

## Rollback

### Rollback to Previous Version

```bash
helm rollback greenfield -n greenfield
```

### Rollback to Specific Revision

```bash
# List history
helm history greenfield -n greenfield

# Rollback to specific revision
helm rollback greenfield 3 -n greenfield
```

### Rollback with Cleanup

```bash
helm rollback greenfield -n greenfield --cleanup-on-fail
```

## Uninstalling

### Basic Uninstall

```bash
helm uninstall greenfield -n greenfield
```

### Keep History

Keep release history for potential rollback:

```bash
helm uninstall greenfield -n greenfield --keep-history
```

### Wait for Deletion

Wait for all resources to be deleted:

```bash
helm uninstall greenfield -n greenfield --wait
```

## Testing and Validation

### Template Rendering

Preview generated manifests without installation:

```bash
helm template greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values my-values.yaml
```

Save output to file:

```bash
helm template greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values my-values.yaml > rendered.yaml
```

### Dry Run

Simulate installation:

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --dry-run \
  --debug
```

### Linting

Validate chart for issues:

```bash
helm lint helm/greenfield-cluster

# With custom values
helm lint helm/greenfield-cluster --values my-values.yaml
```

### Diff Changes

Use helm-diff plugin to see changes before upgrading:

```bash
# Install plugin (use specific version for security)
helm plugin install https://github.com/databus23/helm-diff --version v3.9.0

# Show diff
helm diff upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values my-values.yaml
```

## GitOps Integration

### ArgoCD

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
    path: helm/greenfield-cluster
    helm:
      valueFiles:
        - values-prod.yaml
      parameters:
        - name: fastapi.replicas
          value: "5"
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

### Flux CD

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
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: greenfield-cluster
  namespace: flux-system
spec:
  interval: 10m
  chart:
    spec:
      chart: ./helm/greenfield-cluster
      sourceRef:
        kind: GitRepository
        name: greenfield-cluster
  values:
    fastapi:
      replicas: 5
  valuesFrom:
    - kind: ConfigMap
      name: greenfield-values
```

## Advanced Configuration

### Custom Templates

Override specific templates by creating custom values:

```yaml
# my-values.yaml
fastapi:
  customConfig: |
    [custom]
    setting = value
```

### Dependencies

Add external chart dependencies:

```yaml
# Chart.yaml
dependencies:
  - name: redis
    version: "17.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled
```

Update dependencies:

```bash
helm dependency update helm/greenfield-cluster
```

### Hooks

Use Helm hooks for lifecycle management:

```yaml
# templates/backup-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "greenfield.fullname" . }}-backup
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      containers:
        - name: backup
          image: backup-tool:latest
          command: ["/backup.sh"]
```

## Troubleshooting

### Common Issues

**Release already exists**

```bash
# Uninstall first
helm uninstall greenfield -n greenfield

# Or use upgrade with --install flag
helm upgrade --install greenfield helm/greenfield-cluster
```

**Failed to download chart**

```bash
# Update repository
helm repo update

# Verify chart exists
helm search repo greenfield
```

**Values not applied**

```bash
# Check merged values
helm get values greenfield -n greenfield --all

# Use --reuse-values cautiously
helm upgrade greenfield helm/greenfield-cluster --reuse-values=false
```

**Timeout during installation**

```bash
# Increase timeout
helm install greenfield helm/greenfield-cluster \
  --timeout 15m \
  --wait
```

**Incomplete deletion**

```bash
# Force delete namespace
kubectl delete namespace greenfield --force --grace-period=0

# Check for stuck resources
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get --show-kind --ignore-not-found -n greenfield
```

## Best Practices

1. **Version Control Values**: Keep custom values files in Git
2. **Use Values Files**: Prefer values files over --set for complex configs
3. **Environment Separation**: Different values files per environment
4. **Test Locally**: Use `helm template` before deploying
5. **Atomic Upgrades**: Use `--atomic` flag for production
6. **Resource Limits**: Always set resource requests and limits
7. **Backup Before Upgrade**: Backup data before major upgrades
8. **Monitor Rollouts**: Watch pod status during deployments

## Helm vs Kustomize

| Feature | Helm | Kustomize |
|---------|------|-----------|
| Learning Curve | Lower | Higher |
| Configuration | Values-based | Patch-based |
| Templating | Go templates | No templating |
| GitOps | Via ArgoCD/Flux | Native support |
| Rollback | Built-in | Manual (via Git) |
| Best For | Quick deployments | Precise control |

## Migration to Kustomize

To migrate from Helm to Kustomize:

1. **Render templates**:
   ```bash
   helm template greenfield helm/greenfield-cluster > manifests.yaml
   ```

2. **Organize by component**:
   Split into component directories

3. **Create kustomization.yaml**:
   Reference all components

4. **Test deployment**:
   ```bash
   kubectl apply -k kustomize/base/
   ```

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Helm Chart Development Guide](https://helm.sh/docs/topics/charts/)

## Next Steps

- [Deployment Methods Overview](methods.md)
- [Kustomize Deployment Guide](kustomize.md)
- [Cloud Provider Deployment](aws-eks.md)
- [Security Configuration](../security/overview.md)
