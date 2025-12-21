# Security Best Practices

This guide covers security best practices for deploying and operating the Greenfield Cluster in production environments.

## Overview

Security is implemented in layers across the Greenfield Cluster:

1. **Cluster Security**: RBAC, network policies, pod security
2. **Application Security**: Authentication, authorization, input validation
3. **Data Security**: Encryption at rest and in transit
4. **Network Security**: Service mesh, ingress, egress controls
5. **Operational Security**: Secrets management, auditing, monitoring

## Pre-Deployment Security

### Change Default Passwords

**Critical: Change all default passwords before production deployment!**

```bash
# PostgreSQL
POSTGRES_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic postgres-secret \
  --from-literal=password="$POSTGRES_PASSWORD" \
  --namespace greenfield

# Redis
REDIS_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic redis-secret \
  --from-literal=password="$REDIS_PASSWORD" \
  --namespace greenfield

# MySQL
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic mysql-secret \
  --from-literal=root-password="$MYSQL_ROOT_PASSWORD" \
  --namespace greenfield

# MongoDB
MONGODB_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic mongodb-secret \
  --from-literal=password="$MONGODB_PASSWORD" \
  --namespace greenfield

# Grafana
GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 32)
kubectl create secret generic grafana-secret \
  --from-literal=admin-password="$GRAFANA_ADMIN_PASSWORD" \
  --namespace greenfield
```

### Use Sealed Secrets

Encrypt secrets before storing in Git:

```bash
# Install sealed-secrets controller
kubectl apply -k kustomize/base/sealed-secrets/

# Seal secrets
kubeseal -f secret.yaml -w sealed-secret.yaml

# Commit sealed secrets to Git (safe)
git add sealed-secret.yaml
git commit -m "Add sealed secrets"
```

See [Sealed Secrets Guide](sealed-secrets.md) for details.

## Kubernetes Security

### RBAC (Role-Based Access Control)

Implement least-privilege access:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: greenfield
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: greenfield
subjects:
  - kind: User
    name: developer@example.com
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

### Pod Security Standards

Apply pod security policies:

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

### Security Contexts

Run containers as non-root:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            readOnlyRootFilesystem: true
```

## Network Security

### Network Policies

Restrict pod-to-pod communication:

```yaml
# Default deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: greenfield
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
# Allow specific communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
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

### Istio mTLS

Enable mutual TLS between services:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: greenfield
spec:
  mtls:
    mode: STRICT
```

### Ingress Security

Use TLS for external access:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fastapi-app
                port:
                  number: 8000
```

## Data Security

### Encryption at Rest

Enable etcd encryption on cloud providers:

**AWS EKS:**
```bash
aws eks update-cluster-config \
  --name greenfield-cluster \
  --encryption-config "[{\"resources\":[\"secrets\"],\"provider\":{\"keyArn\":\"arn:aws:kms:region:account:key/key-id\"}}]"
```

**GCP GKE:**
```bash
gcloud container clusters update greenfield-cluster \
  --database-encryption-key projects/PROJECT_ID/locations/LOCATION/keyRings/RING/cryptoKeys/KEY
```

**Azure AKS:**
Enabled by default with Azure-managed keys.

### Encryption in Transit

All communication should use TLS:

1. **Service Mesh**: Istio provides automatic mTLS
2. **Database Connections**: Use SSL/TLS connections
3. **External APIs**: Always use HTTPS

### Sensitive Data Handling

**Never log sensitive data:**

```python
# ❌ BAD
logger.info(f"User password: {password}")

# ✅ GOOD
logger.info("User authentication successful")
```

**Mask sensitive data in logs:**

```python
import logging
import re

class SensitiveDataFilter(logging.Filter):
    def filter(self, record):
        record.msg = re.sub(r'password=[^&\s]+', 'password=***', record.msg)
        return True

logger.addFilter(SensitiveDataFilter())
```

## Application Security

### Input Validation

Always validate and sanitize inputs:

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, validator

class UserInput(BaseModel):
    email: str
    age: int
    
    @validator('email')
    def validate_email(cls, v):
        if '@' not in v:
            raise ValueError('Invalid email')
        return v
    
    @validator('age')
    def validate_age(cls, v):
        if v < 0 or v > 150:
            raise ValueError('Invalid age')
        return v

@app.post("/users")
async def create_user(user: UserInput):
    # Input is validated
    return {"email": user.email}
```

### SQL Injection Prevention

Use parameterized queries:

```python
# ❌ BAD - SQL Injection vulnerable
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# ✅ GOOD - Parameterized query
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

### XSS Prevention

Escape output and use Content Security Policy:

```python
from markupsafe import escape

# Escape user input
safe_input = escape(user_input)

# Add CSP header
@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    return response
```

### API Rate Limiting

Prevent abuse with rate limiting:

```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.get("/api/data")
@limiter.limit("100/minute")
async def get_data():
    return {"data": "value"}
```

## Secrets Management

### External Secret Managers

For production, consider external secret managers:

**AWS Secrets Manager:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: aws-secrets
  target:
    name: postgres-secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/db/password
```

### Kubernetes Secrets Best Practices

1. **Encrypt at Rest**: Enable etcd encryption
2. **RBAC**: Limit who can read secrets
3. **Rotation**: Regularly rotate credentials
4. **Audit**: Monitor secret access
5. **Scope**: Use namespace-scoped secrets

## Authentication and Authorization

Greenfield Cluster includes modular authentication. See:

- [Authentication Architecture](auth-architecture.md)
- [Provider Setup](auth-providers.md)
- [Quick Reference](auth-quickref.md)

### OAuth2/OIDC

```bash
# Install with Azure AD
make auth.install PROVIDER=azuread DOMAIN=example.com

# Protect an application
make auth.protect APP=myapp HOST=myapp.example.com POLICY=group:developers
```

## Monitoring and Auditing

### Enable Audit Logging

**GKE:**
```bash
gcloud container clusters update greenfield-cluster \
  --enable-cloud-logging \
  --enable-cloud-monitoring
```

**EKS:**
```bash
aws eks update-cluster-config \
  --name greenfield-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator"],"enabled":true}]}'
```

### Security Monitoring

Monitor for suspicious activity:

```yaml
# Alert on failed auth attempts
alert: HighAuthFailureRate
expr: |
  rate(authentication_attempts{result="failure"}[5m]) > 10
annotations:
  summary: "High authentication failure rate"
```

### Access Logs

Enable and monitor access logs:

```yaml
# Istio access logging
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logging
spec:
  accessLogging:
    - providers:
        - name: envoy
```

## Vulnerability Management

### Image Scanning

Scan container images for vulnerabilities:

```bash
# Using Trivy
trivy image fastapi-example:latest

# In CI/CD
docker build -t myapp:latest .
trivy image --severity HIGH,CRITICAL myapp:latest
```

### Regular Updates

Keep components updated:

```bash
# Update Kubernetes
# Cloud provider-specific commands

# Update container images
kubectl set image deployment/fastapi-app \
  fastapi-app=fastapi-example:v2.0.0

# Update Helm charts
helm upgrade greenfield helm/greenfield-cluster
```

### Dependency Scanning

Scan application dependencies:

```bash
# Python
pip-audit

# Node.js
npm audit

# Go
go list -json -m all | nancy sleuth
```

## Incident Response

### Preparation

1. **Document procedures**: Incident response playbook
2. **Define roles**: Who responds to incidents
3. **Set up alerts**: Critical security alerts
4. **Backup strategy**: Regular backups of critical data

### Detection

Monitor for:
- Unusual network traffic
- Failed authentication attempts
- Privilege escalation attempts
- Unauthorized pod creation
- Secret access patterns

### Response

```bash
# Isolate compromised pod
kubectl label pod <pod-name> quarantine=true

# Apply network policy to block traffic
kubectl apply -f quarantine-netpol.yaml

# Collect logs
kubectl logs <pod-name> > incident-logs.txt

# Export pod manifest
kubectl get pod <pod-name> -o yaml > compromised-pod.yaml

# Delete compromised resource
kubectl delete pod <pod-name>
```

## Compliance

### GDPR

- Implement data minimization
- Enable audit logging
- Provide data export capabilities
- Implement data deletion

### SOC 2

- Access controls (RBAC)
- Encryption (at rest and in transit)
- Monitoring and alerting
- Audit trails

### PCI DSS

- Network segmentation
- Strong access controls
- Encryption of cardholder data
- Regular security testing

## Security Checklist

### Pre-Production

- [ ] Changed all default passwords
- [ ] Configured Sealed Secrets
- [ ] Enabled RBAC
- [ ] Configured network policies
- [ ] Enabled Istio mTLS
- [ ] Set up TLS for ingress
- [ ] Enabled etcd encryption
- [ ] Configured pod security standards
- [ ] Set up monitoring and alerting
- [ ] Configured backup strategy

### Ongoing

- [ ] Regular security audits
- [ ] Vulnerability scanning
- [ ] Dependency updates
- [ ] Access review
- [ ] Incident response drills
- [ ] Security training

## Additional Resources

- [Security Overview](overview.md)
- [Sealed Secrets](sealed-secrets.md)
- [Authentication Guide](auth-architecture.md)
- [OWASP Kubernetes Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
