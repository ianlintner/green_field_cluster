# App Protection Templates

This directory contains templates for protecting applications with authentication.

## Quick Start

### Protect an Application

```bash
# Using the automation script
./scripts/auth-protect.sh myapp myapp.example.com "group:developers"

# Or manually copy and customize templates
```

## Template Files

- **auth.yaml**: Complete authentication setup for an app
- **virtualservice.yaml**: Istio VirtualService with auth
- **authorization-policy.yaml**: Group/role-based access control
- **request-authentication.yaml**: JWT validation rules

## Usage Patterns

### Pattern 1: Simple Domain Restriction

Restrict access to users from specific email domains:

```yaml
# apps/myapp/auth.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: myapp-domain-auth
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: myapp
  action: ALLOW
  rules:
  - when:
    - key: request.auth.claims[email]
      values:
      - "*@example.com"
```

### Pattern 2: Group-Based Access

Allow only specific groups:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: myapp-group-auth
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: myapp
  action: ALLOW
  rules:
  - when:
    - key: request.auth.claims[groups]
      values:
      - "admins"
      - "developers"
```

### Pattern 3: Path-Based Exemptions

Allow unauthenticated access to specific paths:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: myapp-public-paths
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: myapp
  action: ALLOW
  rules:
  # Public paths (no auth required)
  - to:
    - operation:
        paths:
        - "/health"
        - "/healthz"
        - "/metrics"
        - "/public/*"
```

### Pattern 4: Admin-Only Routes

Protect admin routes with stricter requirements:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: myapp-admin-routes
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: myapp
  action: ALLOW
  rules:
  - to:
    - operation:
        paths:
        - "/admin/*"
    when:
    - key: request.auth.claims[groups]
      values:
      - "admins"
```

## Complete Example

See `auth-template.yaml` for a complete example with:
- VirtualService configuration
- RequestAuthentication for JWT validation
- AuthorizationPolicy with multiple rules
- Path-based access control
- Group-based authorization

## Automation

Use the provided scripts to automate app protection:

```bash
# Install auth module
make auth.install PROVIDER=azuread DOMAIN=example.com

# Protect an app
make auth.protect APP=myapp HOST=myapp.example.com POLICY=group:developers

# Verify configuration
make auth.doctor
```

## Best Practices

1. **Start with least privilege** - Deny by default, allow explicitly
2. **Use label selectors** - Apply policies to specific workloads
3. **Layer policies** - Combine multiple policies for defense in depth
4. **Allow health checks** - Always exclude `/health` and `/metrics`
5. **Test thoroughly** - Verify auth before production deployment
6. **Monitor logs** - Watch for authorization denials
7. **Document exceptions** - Clearly comment why paths are public

## Troubleshooting

### Policy Not Applied
```bash
# Check policy status
kubectl get authorizationpolicy -n greenfield

# View policy details
kubectl describe authorizationpolicy myapp-auth -n greenfield
```

### JWT Not Validated
```bash
# Check RequestAuthentication
kubectl get requestauthentication -n greenfield

# Verify JWKS URL is reachable
curl https://your-idp.com/.well-known/openid-configuration
```

### Authorization Denied
```bash
# Check Istio proxy logs
kubectl logs -n greenfield POD_NAME -c istio-proxy

# Look for authorization denied messages
# Verify JWT claims match policy rules
```
