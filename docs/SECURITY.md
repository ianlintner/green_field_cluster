# Security Configuration Guide

## ⚠️ IMPORTANT: Default Passwords

This repository includes **PLACEHOLDER** passwords for demonstration purposes only. 

**DO NOT USE THESE PASSWORDS IN PRODUCTION!**

### Default Passwords in This Repository

The following components use default passwords that **MUST** be changed:

| Component | Default Password | Location |
|-----------|-----------------|----------|
| PostgreSQL | `changeme123` | `kustomize/base/postgres/kustomization.yaml` |
| MySQL root | `rootpass123` | `kustomize/base/mysql/kustomization.yaml` |
| MySQL user | `changeme123` | `kustomize/base/mysql/kustomization.yaml` |
| MongoDB | `changeme123` | `kustomize/base/mongodb/kustomization.yaml` |
| Grafana admin | `admin123` | `kustomize/base/grafana/kustomization.yaml` |

### How to Change Passwords

#### Method 1: Using Sealed Secrets (Recommended for Production)

1. **Install kubeseal CLI** (see main documentation)

2. **Create strong passwords**:
```bash
# Generate a strong password
openssl rand -base64 32
```

3. **Create a secret file**:
```bash
# Example for PostgreSQL
kubectl create secret generic postgres-secret \
  --from-literal=password="YOUR-STRONG-PASSWORD-HERE" \
  --dry-run=client -o yaml > postgres-secret.yaml
```

4. **Seal the secret**:
```bash
kubeseal -f postgres-secret.yaml \
  -w postgres-sealed-secret.yaml \
  --controller-namespace=kube-system
```

5. **Apply the sealed secret**:
```bash
kubectl apply -f postgres-sealed-secret.yaml -n greenfield
```

6. **Remove the plain secret file**:
```bash
rm postgres-secret.yaml
# Only commit the sealed-secret.yaml to Git
```

#### Method 2: Using Kustomize SecretGenerator

Edit the kustomization.yaml files to use your own passwords:

```yaml
# kustomize/base/postgres/kustomization.yaml
secretGenerator:
  - name: postgres-secret
    literals:
      - password=YOUR-STRONG-PASSWORD-HERE
```

**Note**: This method stores passwords in plain text in your Git repository. Use sealed-secrets for production.

#### Method 3: Using External Secret Management

For production environments, consider using:
- **AWS Secrets Manager** with External Secrets Operator
- **HashiCorp Vault** with Vault Secrets Operator
- **Google Secret Manager** with External Secrets Operator
- **Azure Key Vault** with External Secrets Operator

### Password Requirements

For production use, ensure passwords meet these minimum requirements:

- At least 16 characters long
- Include uppercase and lowercase letters
- Include numbers
- Include special characters
- Not based on dictionary words
- Unique for each service

### Password Generation Examples

```bash
# Generate a 32-character random password
openssl rand -base64 32

# Generate a password with specific requirements
pwgen -sync 32 1

# Using Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## Kubernetes Secrets Security Best Practices

### 1. Enable Encryption at Rest

Ensure your Kubernetes cluster has encryption at rest enabled for secrets:

```yaml
# Example encryption config for kube-apiserver
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-secret>
      - identity: {}
```

### 2. Use RBAC to Restrict Secret Access

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: greenfield
  name: secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["specific-secret-name"]
    verbs: ["get"]
```

### 3. Use Network Policies

Restrict which pods can access which services:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-policy
  namespace: greenfield
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: fastapi-app
      ports:
        - protocol: TCP
          port: 5432
```

### 4. Rotate Secrets Regularly

Establish a secret rotation schedule:
- Critical secrets: Every 30 days
- Moderate secrets: Every 90 days
- Low-risk secrets: Every 180 days

### 5. Audit Secret Access

Enable audit logging in your Kubernetes cluster to track secret access:

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    resources:
      - group: ""
        resources: ["secrets"]
```

## Additional Security Measures

### Enable Pod Security Standards

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: greenfield
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Use Service Mesh for mTLS

Istio provides automatic mutual TLS between services. This cluster has mTLS enabled with STRICT mode:

**Current Configuration:**
- ✅ **Namespace injection enabled**: `greenfield` namespace has `istio-injection: enabled` label
- ✅ **STRICT mTLS enforced**: All services in `greenfield` and `istio-system` namespaces require mTLS
- ✅ **Automatic sidecar injection**: All pods receive Istio sidecars automatically
- ✅ **Transparent encryption**: No application code changes needed

The following policies are configured:

```yaml
# PeerAuthentication for greenfield namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: greenfield
spec:
  mtls:
    mode: STRICT
---
# DestinationRule for client-side mTLS
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default-mtls
  namespace: greenfield
spec:
  host: "*.greenfield.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

**Verify mTLS is enabled:**

```bash
# Check namespace injection label
kubectl get namespace greenfield -o yaml | grep istio-injection

# Verify PeerAuthentication policies
kubectl get peerauthentication -A

# Check if pods have Istio sidecars
kubectl get pods -n greenfield

# Verify mTLS for a specific service
istioctl authn tls-check <pod-name>.greenfield <service-name>.greenfield.svc.cluster.local
```

See [kustomize/base/istio/README.md](../kustomize/base/istio/README.md) for detailed mTLS configuration.

### Scan Images for Vulnerabilities

Use tools like:
- Trivy
- Clair
- Anchore

```bash
# Example with Trivy
trivy image postgres:16-alpine
trivy image redis:7.2-alpine
trivy image fastapi-example:latest
```

## Incident Response

If credentials are compromised:

1. **Immediately rotate all affected credentials**
2. **Check audit logs for unauthorized access**
3. **Investigate the scope of the breach**
4. **Update access controls and permissions**
5. **Document the incident and response**
6. **Review and improve security practices**

## Security Checklist

Before deploying to production:

- [ ] All default passwords changed to strong, unique passwords
- [ ] Sealed Secrets or external secret manager configured
- [ ] Kubernetes secrets encryption at rest enabled
- [ ] RBAC policies configured for least-privilege access
- [ ] Network policies implemented
- [x] Istio mTLS enabled with STRICT mode for all services
- [x] Automatic Istio sidecar injection enabled for greenfield namespace
- [ ] Container images scanned for vulnerabilities
- [ ] Pod security standards enforced
- [ ] Audit logging enabled
- [ ] Secret rotation schedule established
- [ ] Backup and disaster recovery plan in place
- [ ] Monitoring and alerting configured

## Resources

- [Kubernetes Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
