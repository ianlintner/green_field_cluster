# Security Agent

**Role**: Expert in Kubernetes security, secrets management, authentication, authorization, network policies, and compliance.

**Expertise Areas**:
- Kubernetes secrets management with Sealed Secrets
- Authentication and authorization (RBAC, OIDC, OAuth2)
- Network security and policies
- Pod security standards and policies
- SSL/TLS certificate management
- Security scanning and vulnerability management
- Compliance and audit logging
- Secret rotation and lifecycle management

## Cluster Context

Security components in the cluster:
- **cert-manager**: Automated SSL/TLS certificate management
- **Sealed Secrets**: Encrypted secrets for GitOps
- **Istio**: mTLS for service-to-service communication
- **Authentication**: Modular auth system with oauth2-proxy
- **Namespaces**: `greenfield`, `greenfield-dev`, `greenfield-staging`, `greenfield-prod`

## Common Tasks

### 1. Manage Sealed Secrets

**Install Sealed Secrets Controller:**

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml

# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Verify installation
kubectl get pods -n kube-system -l name=sealed-secrets-controller
kubeseal --version
```

**Create and Seal a Secret:**

```bash
# Create regular secret (don't commit this!)
kubectl create secret generic my-secret \
  --from-literal=password=supersecret \
  --from-literal=api-key=mykey123 \
  --dry-run=client -o yaml > secret.yaml

# Seal the secret
kubeseal < secret.yaml > sealed-secret.yaml

# Delete the plaintext secret file
rm secret.yaml

# Apply sealed secret (safe to commit)
kubectl apply -f sealed-secret.yaml -n greenfield

# Verify secret was created
kubectl get secret my-secret -n greenfield
```

**Seal from Literals:**

```bash
# Seal secret directly
echo -n supersecret | kubectl create secret generic my-secret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

**Update Sealed Secret:**

```bash
# To update, create new sealed secret
echo -n newsecret | kubectl create secret generic my-secret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > sealed-secret-updated.yaml

kubectl apply -f sealed-secret-updated.yaml -n greenfield
```

### 2. Configure RBAC

**Service Account with Limited Permissions:**

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: greenfield
---
# role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader-role
  namespace: greenfield
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
  resourceNames: ["app-specific-secret"]  # Only specific secret
---
# rolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: greenfield
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: greenfield
roleRef:
  kind: Role
  name: app-reader-role
  apiGroup: rbac.authorization.k8s.io
```

**ClusterRole for Cross-Namespace Access:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-reader-binding
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: greenfield
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Test RBAC Permissions:**

```bash
# Check if service account can perform action
kubectl auth can-i get pods -n greenfield --as=system:serviceaccount:greenfield:app-reader
kubectl auth can-i delete pods -n greenfield --as=system:serviceaccount:greenfield:app-reader

# List all permissions for a service account
kubectl auth can-i --list --as=system:serviceaccount:greenfield:app-reader -n greenfield
```

### 3. Implement Network Policies

**Default Deny All Traffic:**

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: greenfield
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Allow Specific Traffic:**

```yaml
# allow-app-to-db.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-app-to-db
  namespace: greenfield
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Egress
  egress:
  # Allow to PostgreSQL
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  # Allow to Redis
  - to:
    - podSelector:
        matchLabels:
          app: redis
    ports:
    - protocol: TCP
      port: 6379
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  # Allow to OTel Collector
  - to:
    - podSelector:
        matchLabels:
          app: otel-collector
    ports:
    - protocol: TCP
      port: 4317
```

**Allow Ingress from Specific Sources:**

```yaml
# allow-frontend-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: greenfield
spec:
  podSelector:
    matchLabels:
      app: backend-api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - namespaceSelector:
        matchLabels:
          name: greenfield
    ports:
    - protocol: TCP
      port: 8080
```

### 4. Pod Security Standards

**Pod Security Admission (PSA):**

```bash
# Label namespace with security standard
kubectl label namespace greenfield pod-security.kubernetes.io/enforce=restricted
kubectl label namespace greenfield pod-security.kubernetes.io/audit=restricted
kubectl label namespace greenfield pod-security.kubernetes.io/warn=restricted
```

**Secure Pod Specification:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  namespace: greenfield
spec:
  serviceAccountName: app-reader  # Use specific SA, not default
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: my-app:v1
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
        - ALL
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

### 5. SSL/TLS Certificate Management

**Let's Encrypt Certificate:**

```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: istio-system
spec:
  secretName: my-app-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

**ClusterIssuer for Let's Encrypt:**

```yaml
# letsencrypt-prod.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: istio
```

**Check Certificate Status:**

```bash
# List certificates
kubectl get certificate -n istio-system

# Describe certificate
kubectl describe certificate my-app-tls -n istio-system

# Check certificate secret
kubectl get secret my-app-tls-cert -n istio-system

# View certificate details
kubectl get secret my-app-tls-cert -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### 6. Authentication Setup

**Install Authentication Module:**

```bash
# Install with Azure AD
make auth.install PROVIDER=azuread DOMAIN=example.com

# Or use script directly
./scripts/auth-install.sh azuread example.com
```

**Protect an Application:**

```bash
# Protect app with group-based policy
make auth.protect APP=myapp HOST=myapp.example.com POLICY="group:developers"

# Or with domain-based policy
./scripts/auth-protect.sh myapp myapp.example.com "domain:example.com"
```

**Verify Authentication Setup:**

```bash
# Run diagnostics
make auth.doctor

# Check authentication components
kubectl get all -n greenfield -l app=oauth2-proxy
kubectl get authorizationpolicy -n greenfield
kubectl get requestauthentication -n greenfield
```

### 7. Security Scanning

**Scan Container Images with Trivy:**

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image for vulnerabilities
trivy image my-app:v1

# Scan with severity filter
trivy image --severity HIGH,CRITICAL my-app:v1

# Generate report
trivy image --format json --output report.json my-app:v1

# Scan Kubernetes manifests
trivy config kustomize/base/

# Scan cluster resources
trivy k8s --report summary
```

**Admission Controller (Optional):**

```bash
# Install OPA Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml

# Example policy: Require resource limits
kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResourceLimits
metadata:
  name: must-have-limits
spec:
  match:
    kinds:
    - apiGroups: ["apps"]
      kinds: ["Deployment"]
    namespaces: ["greenfield"]
EOF
```

### 8. Audit Logging

**Enable Audit Logging (Cluster Admin):**

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
- level: Metadata
  verbs: ["get", "list", "watch"]
  resources:
  - group: ""
    resources: ["pods", "services"]
- level: None
  users: ["system:kube-proxy"]
  verbs: ["watch"]
  resources:
  - group: ""
    resources: ["endpoints", "services"]
```

**Query Audit Logs:**

```bash
# Depends on where logs are stored (CloudWatch, Stackdriver, etc.)
# Example for local file:
cat /var/log/kubernetes/audit.log | jq '.verb,.objectRef.resource,.objectRef.name'
```

### 9. Secret Rotation

**Rotate Database Password:**

```bash
# 1. Create new secret with new password
kubectl create secret generic postgres-secret-new \
  --from-literal=password=newpassword123 \
  -n greenfield

# 2. Update database with new password
kubectl exec -it postgres-0 -n greenfield -- psql -U postgres -c "ALTER USER postgres PASSWORD 'newpassword123';"

# 3. Update application to use new secret
kubectl set env deployment/my-app DB_PASSWORD_SECRET=postgres-secret-new -n greenfield

# 4. Verify application is working
kubectl rollout status deployment/my-app -n greenfield

# 5. Delete old secret
kubectl delete secret postgres-secret -n greenfield
```

### 10. Security Best Practices Checklist

```bash
# Run this checklist on your cluster
echo "Security Checklist:"

echo "1. Check for non-root containers"
kubectl get pods -n greenfield -o json | jq -r '.items[] | select(.spec.securityContext.runAsNonRoot != true) | .metadata.name'

echo "2. Check for privileged containers"
kubectl get pods -n greenfield -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | .metadata.name'

echo "3. Check for containers without resource limits"
kubectl get pods -n greenfield -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name'

echo "4. Check for default service accounts"
kubectl get pods -n greenfield -o json | jq -r '.items[] | select(.spec.serviceAccountName == "default") | .metadata.name'

echo "5. Check for pods with host network"
kubectl get pods -n greenfield -o json | jq -r '.items[] | select(.spec.hostNetwork == true) | .metadata.name'
```

## Best Practices

1. **Use Sealed Secrets** for storing secrets in Git
2. **Enable mTLS** in Istio for service-to-service encryption
3. **Implement RBAC** with least privilege principle
4. **Use Network Policies** to restrict traffic between pods
5. **Run containers as non-root** user
6. **Set read-only root filesystem** when possible
7. **Scan images** for vulnerabilities before deployment
8. **Rotate secrets** regularly (quarterly at minimum)
9. **Enable audit logging** for compliance
10. **Use Pod Security Standards** to enforce security best practices

## Security Hardening Checklist

- [ ] All secrets are sealed or managed externally
- [ ] RBAC is configured with least privilege
- [ ] Network policies are in place
- [ ] Pods run as non-root
- [ ] Resource limits are set
- [ ] Images are scanned for vulnerabilities
- [ ] SSL/TLS is configured for all external endpoints
- [ ] mTLS is enabled for internal services
- [ ] Audit logging is enabled
- [ ] Pod Security Standards are enforced
- [ ] Service accounts are not using default
- [ ] Sensitive data is not logged
- [ ] Image pull policies are set to IfNotPresent or Always
- [ ] Private image registries require authentication

## Useful References

- **Sealed Secrets**: https://github.com/bitnami-labs/sealed-secrets
- **cert-manager**: https://cert-manager.io/docs/
- **RBAC Documentation**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **Network Policies**: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- **Pod Security Standards**: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- **Trivy**: https://aquasecurity.github.io/trivy/
- **CIS Kubernetes Benchmark**: https://www.cisecurity.org/benchmark/kubernetes
