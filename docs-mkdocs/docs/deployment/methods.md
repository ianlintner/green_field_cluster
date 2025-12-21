# Deployment Methods

Greenfield Cluster supports multiple deployment methods to suit different workflows and use cases. Choose the method that best fits your team's needs and infrastructure management approach.

## Overview

| Method | Best For | Complexity | Customization | GitOps Support |
|--------|----------|------------|---------------|----------------|
| **Kustomize** | GitOps workflows, precise control | Medium | Excellent | ✅ Native |
| **Helm** | Quick deployment, parameter-driven | Low | Good | ✅ Via ArgoCD/Flux |
| **Direct kubectl** | Learning, testing | Low | Limited | ❌ Manual |

## Deployment Method Comparison

### Kustomize (Recommended)

**Best for:**
- Teams practicing GitOps
- Need for environment-specific configurations
- Precise control over Kubernetes manifests
- Complex multi-environment deployments

**Advantages:**
- ✅ Native Kubernetes support (built into kubectl)
- ✅ Declarative configuration management
- ✅ Environment-specific overlays
- ✅ Patch-based customization
- ✅ No templating language to learn
- ✅ Perfect for GitOps (ArgoCD, Flux)

**Disadvantages:**
- ⚠️ Steeper learning curve than Helm
- ⚠️ More verbose than templating
- ⚠️ Requires understanding of overlay structure

**Learn more:** [Kustomize Deployment Guide](kustomize.md)

### Helm

**Best for:**
- Quick deployments
- Parameter-driven configuration
- Existing Helm infrastructure
- Package distribution

**Advantages:**
- ✅ Simple value-based configuration
- ✅ One-command deployment
- ✅ Built-in rollback support
- ✅ Release management
- ✅ Easy to share and distribute

**Disadvantages:**
- ⚠️ Go templating can be complex
- ⚠️ Less precise than Kustomize
- ⚠️ Chart maintenance overhead

**Learn more:** [Helm Deployment Guide](helm.md)

### Direct kubectl

**Best for:**
- Learning and experimentation
- Quick testing
- Simple deployments

**Advantages:**
- ✅ Simplest to understand
- ✅ Direct control
- ✅ No additional tools

**Disadvantages:**
- ⚠️ No configuration management
- ⚠️ Manual updates required
- ⚠️ Not suitable for production
- ⚠️ No environment-specific configuration

## Quick Start Examples

### Using Kustomize

Deploy base configuration:
```bash
kubectl apply -k kustomize/base/
```

Deploy environment-specific overlay:
```bash
# Development
kubectl apply -k kustomize/overlays/dev/

# Staging
kubectl apply -k kustomize/overlays/staging/

# Production
kubectl apply -k kustomize/overlays/prod/
```

### Using Helm

Basic deployment:
```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace
```

With custom values:
```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values my-values.yaml
```

### Using Direct kubectl

Apply individual components:
```bash
kubectl apply -f kustomize/base/namespace/namespace.yaml
kubectl apply -f kustomize/base/redis/
kubectl apply -f kustomize/base/postgres/
```

## Environment Management

### Development Environment

**Characteristics:**
- Minimal resource requirements
- Single replicas for most components
- Relaxed resource limits
- Suitable for local testing

**Kustomize:**
```bash
kubectl apply -k kustomize/overlays/dev/
```

**Helm:**
```bash
helm install greenfield helm/greenfield-cluster \
  --values helm/greenfield-cluster/values-dev.yaml
```

### Staging Environment

**Characteristics:**
- Production-like setup
- Medium resource allocation
- Some redundancy
- Pre-production testing

**Kustomize:**
```bash
kubectl apply -k kustomize/overlays/staging/
```

**Helm:**
```bash
helm install greenfield helm/greenfield-cluster \
  --values helm/greenfield-cluster/values-staging.yaml
```

### Production Environment

**Characteristics:**
- High availability
- Multiple replicas
- Resource guarantees
- Full observability

**Kustomize:**
```bash
kubectl apply -k kustomize/overlays/prod/
```

**Helm:**
```bash
helm install greenfield helm/greenfield-cluster \
  --values helm/greenfield-cluster/values-prod.yaml
```

## GitOps Integration

### ArgoCD

**Kustomize Application:**
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
```

**Helm Application:**
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
  destination:
    server: https://kubernetes.default.svc
    namespace: greenfield
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Flux CD

**Kustomization:**
```yaml
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
    name: green-field-cluster
```

**HelmRelease:**
```yaml
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
        name: green-field-cluster
  values:
    # Override values here
```

## Component Selection

### Removing Unused Components

**Kustomize:**
Edit `kustomize/base/kustomization.yaml`:
```yaml
resources:
  - namespace
  - redis
  - postgres
  # - mysql      # Not needed
  # - mongodb    # Not needed
  - kafka
  - istio
  - otel-collector
  - jaeger
  - prometheus
  - grafana
```

**Helm:**
```yaml
# values.yaml
mysql:
  enabled: false
mongodb:
  enabled: false
```

### Adding Custom Components

**Kustomize:**
1. Create component directory in `kustomize/base/`
2. Add component to `kustomization.yaml`
3. Apply overlay-specific customizations

**Helm:**
1. Add subchart to `helm/greenfield-cluster/charts/`
2. Configure in `values.yaml`
3. Deploy with updated chart

## Upgrading Deployments

### Kustomize Upgrades

```bash
# Pull latest changes
git pull origin main

# Review changes
kubectl diff -k kustomize/overlays/prod/

# Apply updates
kubectl apply -k kustomize/overlays/prod/
```

### Helm Upgrades

```bash
# Update repository
git pull origin main

# Review changes
helm diff upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield

# Upgrade release
helm upgrade greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --values my-values.yaml
```

## Rollback Procedures

### Kustomize Rollback

```bash
# Revert to previous Git commit
git revert HEAD
git push

# Or manually apply previous version
git checkout <previous-commit>
kubectl apply -k kustomize/overlays/prod/
git checkout main
```

### Helm Rollback

```bash
# List release history
helm history greenfield -n greenfield

# Rollback to previous release
helm rollback greenfield -n greenfield

# Rollback to specific revision
helm rollback greenfield 3 -n greenfield
```

## Validation and Testing

### Pre-Deployment Validation

**Kustomize:**
```bash
# Generate and review manifests
kubectl kustomize kustomize/overlays/prod/ > output.yaml

# Dry-run deployment
kubectl apply -k kustomize/overlays/prod/ --dry-run=client

# Server-side dry-run
kubectl apply -k kustomize/overlays/prod/ --dry-run=server
```

**Helm:**
```bash
# Template and review
helm template greenfield helm/greenfield-cluster \
  --values my-values.yaml > output.yaml

# Dry-run
helm install greenfield helm/greenfield-cluster \
  --dry-run --debug
```

### Post-Deployment Validation

```bash
# Check pod status
kubectl get pods -n greenfield

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod \
  --all -n greenfield --timeout=600s

# Check service endpoints
kubectl get svc -n greenfield

# View resource usage
kubectl top pods -n greenfield
```

## Cloud Provider Deployment

Deploy to specific cloud providers with platform-specific configurations:

- **AWS EKS**: [AWS EKS Deployment Guide](aws-eks.md)
- **GCP GKE**: [GCP GKE Deployment Guide](gcp-gke.md)
- **Azure AKS**: [Azure AKS Deployment Guide](azure-aks.md)

## Troubleshooting

### Common Issues

**Namespace already exists:**
```bash
# Skip namespace creation or delete existing
kubectl delete namespace greenfield
kubectl apply -k kustomize/overlays/prod/
```

**Storage class not found:**
```bash
# List available storage classes
kubectl get storageclass

# Update manifests with correct storage class
# Edit PVC definitions in component directories
```

**ImagePullBackOff:**
```bash
# Check image names and tags
kubectl describe pod <pod-name> -n greenfield

# Ensure image registry is accessible
# Build and push images if using custom builds
```

**Resource constraints:**
```bash
# Check node resources
kubectl top nodes

# Scale down non-essential components
# Adjust resource requests/limits
```

## Best Practices

1. **Use Version Control**: Always commit configuration changes to Git
2. **Environment Isolation**: Use separate namespaces or clusters for dev/staging/prod
3. **Secret Management**: Use Sealed Secrets or external secret managers
4. **Resource Limits**: Always set resource requests and limits
5. **Health Checks**: Configure readiness and liveness probes
6. **Monitoring**: Deploy observability stack before applications
7. **Backup**: Regular backups of persistent data
8. **Documentation**: Document custom configurations and changes

## Next Steps

- [Kustomize Deployment Guide](kustomize.md) - Detailed Kustomize instructions
- [Helm Deployment Guide](helm.md) - Complete Helm deployment guide
- [Cloud Provider Guides](aws-eks.md) - Platform-specific deployment
- [Security Configuration](../security/overview.md) - Secure your deployment
