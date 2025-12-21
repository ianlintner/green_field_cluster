# Sealed Secrets

Sealed Secrets provides a secure way to store Kubernetes secrets in Git by encrypting them before they're committed to version control.

## Overview

Sealed Secrets consists of two components:

1. **Controller**: Kubernetes operator that decrypts sealed secrets
2. **kubeseal CLI**: Tool to encrypt secrets

### Why Sealed Secrets?

- ✅ **GitOps-Friendly**: Store encrypted secrets in Git
- ✅ **One-Way Encryption**: Secrets can only be decrypted by the controller
- ✅ **Public Key Encryption**: Encrypt anywhere, decrypt only in cluster
- ✅ **Namespace-Scoped**: Secrets are scoped to specific namespaces
- ✅ **Easy Key Rotation**: Built-in support for key rotation

## Installation

### Install Controller

Using the provided manifests:

```bash
kubectl apply -k kustomize/base/sealed-secrets/
```

Or install directly:

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
```

Using Helm:

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set-string fullnameOverride=sealed-secrets-controller
```

### Install kubeseal CLI

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Windows:**
```powershell
# Using Chocolatey
choco install kubeseal

# Or download from GitHub releases
# https://github.com/bitnami-labs/sealed-secrets/releases
```

### Verify Installation

```bash
# Check controller is running
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Test kubeseal
kubeseal --version
```

## Usage

### Basic Workflow

1. Create a regular Kubernetes secret (don't apply!)
2. Encrypt it with kubeseal
3. Commit the sealed secret to Git
4. Apply the sealed secret to cluster
5. Controller decrypts it automatically

### Example: Database Password

```bash
# 1. Create secret (dry-run, don't apply)
kubectl create secret generic postgres-secret \
  --from-literal=password='mySecurePassword123!' \
  --namespace greenfield \
  --dry-run=client \
  -o yaml > postgres-secret.yaml

# 2. Seal the secret
kubeseal -f postgres-secret.yaml -w postgres-sealed-secret.yaml \
  --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller

# 3. Apply sealed secret
kubectl apply -f postgres-sealed-secret.yaml

# 4. Verify decrypted secret exists
kubectl get secret postgres-secret -n greenfield
```

### Inline Encryption

Encrypt directly from stdin:

```bash
echo -n 'my-secure-password' | kubectl create secret generic my-secret \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -o yaml | \
kubeseal -o yaml > my-sealed-secret.yaml
```

### Multiple Values

```bash
kubectl create secret generic app-secrets \
  --from-literal=db-password='dbpass123' \
  --from-literal=api-key='apikey456' \
  --from-literal=jwt-secret='jwtsecret789' \
  --namespace greenfield \
  --dry-run=client \
  -o yaml | \
kubeseal -o yaml > app-sealed-secrets.yaml
```

### From Files

```bash
# Create secret from file
kubectl create secret generic tls-cert \
  --from-file=tls.crt=./cert.pem \
  --from-file=tls.key=./key.pem \
  --namespace greenfield \
  --dry-run=client \
  -o yaml | \
kubeseal -o yaml > tls-sealed-secret.yaml
```

## Scopes

Sealed secrets support three scopes:

### Strict (Default)

Secret is bound to specific name and namespace:

```bash
kubeseal --scope strict -f secret.yaml -w sealed-secret.yaml
```

### Namespace-Wide

Secret can be used in any name within the namespace:

```bash
kubeseal --scope namespace-wide -f secret.yaml -w sealed-secret.yaml
```

### Cluster-Wide

Secret can be used anywhere in the cluster:

```bash
kubeseal --scope cluster-wide -f secret.yaml -w sealed-secret.yaml
```

## Examples in Greenfield Cluster

### PostgreSQL Credentials

```bash
kubectl create secret generic postgres-secret \
  --from-literal=POSTGRES_PASSWORD='changeme' \
  --from-literal=POSTGRES_USER='postgres' \
  --namespace greenfield \
  --dry-run=client -o yaml | \
kubeseal -o yaml > kustomize/base/postgres/sealed-secret.yaml
```

### Redis Password

```bash
kubectl create secret generic redis-secret \
  --from-literal=redis-password='redis123' \
  --namespace greenfield \
  --dry-run=client -o yaml | \
kubeseal -o yaml > kustomize/base/redis/sealed-secret.yaml
```

### Grafana Admin Password

```bash
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-password='admin123' \
  --namespace greenfield \
  --dry-run=client -o yaml | \
kubeseal -o yaml > kustomize/base/grafana/sealed-secret.yaml
```

## Key Management

### Get Public Key

```bash
# Fetch public key
kubeseal --fetch-cert > pub-cert.pem

# Use public key for offline encryption
kubeseal --cert=pub-cert.pem -f secret.yaml -w sealed-secret.yaml
```

### Backup Private Key

```bash
# Backup the private key (KEEP THIS SECURE!)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Store in secure location (password manager, vault, etc.)
```

### Restore Private Key

```bash
# In case of cluster migration or disaster recovery
kubectl apply -f sealed-secrets-key-backup.yaml -n kube-system

# Restart controller
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

### Key Rotation

Sealed secrets automatically manages key rotation. By default:

- New key generated every 30 days
- Old keys retained for decryption
- New sealing uses latest key

## CI/CD Integration

### GitHub Actions

```yaml
name: Seal Secrets
on: [push]

jobs:
  seal-secrets:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install kubeseal
        run: |
          wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
          tar xfz kubeseal-0.24.5-linux-amd64.tar.gz
          sudo install -m 755 kubeseal /usr/local/bin/kubeseal
      
      - name: Seal secrets
        run: |
          kubeseal --cert=pub-cert.pem \
            -f secrets/db-secret.yaml \
            -w secrets/db-sealed-secret.yaml
```

### GitLab CI

```yaml
seal-secrets:
  image: bitnami/sealed-secrets:latest
  script:
    - kubeseal --cert=pub-cert.pem -f secret.yaml -w sealed-secret.yaml
  artifacts:
    paths:
      - sealed-secret.yaml
```

## Troubleshooting

### Controller Not Found

```bash
# Check controller pods
kubectl get pods -n kube-system -l name=sealed-secrets-controller

# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller
```

### Decryption Failures

```bash
# Check sealed secret status
kubectl get sealedsecrets -n greenfield

# Check events
kubectl describe sealedsecret <name> -n greenfield

# Common causes:
# - Wrong namespace
# - Controller not running
# - Sealed secret created with different certificate
```

### Re-seal After Key Rotation

```bash
# Get current certificate
kubeseal --fetch-cert > new-cert.pem

# Re-seal secrets with new certificate
kubeseal --cert=new-cert.pem -f secret.yaml -w sealed-secret.yaml
```

## Best Practices

1. **Never Commit Unsealed Secrets**: Always use `.gitignore` for `*-secret.yaml`
2. **Backup Private Keys**: Store controller keys securely
3. **Use Strict Scope**: Unless you have a specific need for wider scope
4. **Automate Sealing**: Integrate into CI/CD pipelines
5. **Rotate Keys**: Follow key rotation schedule
6. **Test Recovery**: Regularly test key backup/restore procedures
7. **Audit**: Monitor sealed secret access and decryption

## Security Considerations

### What Sealed Secrets Protects

✅ Secrets in Git repositories  
✅ Secrets in CI/CD logs  
✅ Unauthorized decryption outside cluster

### What Sealed Secrets Does NOT Protect

❌ Secrets in memory (use CSI drivers)  
❌ Secrets from cluster admins  
❌ Secrets from etcd (use encryption at rest)  
❌ Secrets in application logs

### Additional Security Layers

For comprehensive secret security:

1. **Encryption at Rest**: Enable etcd encryption
2. **RBAC**: Restrict who can access secrets
3. **External Secret Managers**: Consider Vault, AWS Secrets Manager
4. **Audit Logging**: Enable audit logs for secret access
5. **Network Policies**: Restrict pod-to-pod communication

## Additional Resources

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Security Overview](overview.md)
- [Best Practices](best-practices.md)
- [Authentication Guide](auth-architecture.md)
