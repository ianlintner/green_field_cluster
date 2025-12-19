# Authentication Quick Reference

Quick reference for common authentication tasks.

## Installation

### Install with Azure AD
```bash
make auth.install PROVIDER=azuread DOMAIN=example.com
```

### Install with Google
```bash
make auth.install PROVIDER=google DOMAIN=example.com
```

### Install with GitHub
```bash
make auth.install PROVIDER=github DOMAIN=example.com
```

### Install with Okta SAML
```bash
make auth.install PROVIDER=okta-saml DOMAIN=example.com
```

## Protection

### Protect an app with group-based access
```bash
make auth.protect APP=myapp HOST=myapp.example.com POLICY=group:developers
```

### Protect an app with domain restriction
```bash
make auth.protect APP=blog HOST=blog.example.com POLICY=domain:example.com
```

### Protect an app - allow all authenticated users
```bash
make auth.protect APP=docs HOST=docs.example.com POLICY=public
```

## Verification

### Check auth module status
```bash
make auth.doctor
```

### View oauth2-proxy logs
```bash
kubectl logs -n greenfield -l app=oauth2-proxy -f
```

### Check protected apps
```bash
kubectl get virtualservice -n greenfield -l auth-enabled=true
```

### View authorization policies
```bash
kubectl get authorizationpolicy -n greenfield
```

## Troubleshooting

### Redirect loop
```bash
# Check cookie domains
kubectl get configmap oauth2-proxy-config -n greenfield -o yaml

# Check redirect URL
kubectl get configmap oauth2-proxy-config -n greenfield -o jsonpath='{.data.redirect-url}'
```

### Groups not in JWT
```bash
# Decode JWT to check claims
# Get token from browser DevTools → Application → Cookies
# Or from X-Auth-Request-Access-Token header

TOKEN="eyJ..."
echo $TOKEN | cut -d. -f2 | base64 -d | jq .
```

### Authorization denied
```bash
# Check authorization policies
kubectl get authorizationpolicy -n greenfield -o yaml

# Check Istio sidecar logs
kubectl logs -n greenfield POD_NAME -c istio-proxy
```

## Configuration Updates

### Update oauth2-proxy configuration
```bash
kubectl edit configmap oauth2-proxy-config -n greenfield
kubectl rollout restart deployment oauth2-proxy -n greenfield
```

### Update secrets
```bash
kubectl delete secret oauth2-proxy-secret -n greenfield
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=NEW_CLIENT_ID \
  --from-literal=client-secret=NEW_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

### Add environment variable to oauth2-proxy
```bash
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_SKIP_OIDC_DISCOVERY=false
```

## Provider-Specific Commands

### Azure AD - Enable group claims
```bash
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_OIDC_GROUPS_CLAIM=groups
```

### GitHub - Restrict to organization
```bash
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_GITHUB_ORG=your-org
```

### Google - Restrict to domain
```bash
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_GOOGLE_GROUP=your-company.com
```

## Common kubectl Commands

### Get all auth resources
```bash
kubectl get deployment,service,configmap,secret \
  -n greenfield -l app=oauth2-proxy
```

### Get all Istio auth resources
```bash
kubectl get gateway,virtualservice,requestauthentication,authorizationpolicy \
  -n greenfield,istio-system
```

### Describe oauth2-proxy deployment
```bash
kubectl describe deployment oauth2-proxy -n greenfield
```

### Check pod status
```bash
kubectl get pods -n greenfield -l app=oauth2-proxy -o wide
```

### Port forward to oauth2-proxy
```bash
kubectl port-forward -n greenfield svc/oauth2-proxy 4180:4180
# Access http://localhost:4180/ping
```

## Testing Authentication

### Test without auth (should get 302 redirect)
```bash
curl -v https://myapp.example.com/ 2>&1 | grep -i location
```

### Test health endpoint (should return 200)
```bash
curl -v https://myapp.example.com/health
```

### Test with cookie
```bash
# After authentication, save cookies
curl -c cookies.txt https://myapp.example.com/

# Use cookies for subsequent requests
curl -b cookies.txt https://myapp.example.com/api/data
```

## Useful Queries

### List all protected applications
```bash
kubectl get virtualservice -n greenfield -l auth-enabled=true \
  -o custom-columns=NAME:.metadata.name,HOST:.spec.hosts[0]
```

### Check which apps require specific groups
```bash
kubectl get authorizationpolicy -n greenfield -o yaml | \
  grep -A 5 "request.auth.claims\[groups\]"
```

### Find apps with public paths
```bash
kubectl get authorizationpolicy -n greenfield -o yaml | \
  grep -B 5 "/health"
```

## Cleanup

### Remove auth from an app
```bash
kubectl delete virtualservice,authorizationpolicy,requestauthentication \
  -n greenfield -l app=myapp
```

### Uninstall auth module
```bash
kubectl delete -k kustomize/base/auth/overlays/provider-azuread/
```

### Remove all auth resources
```bash
kubectl delete namespace greenfield
# Or selectively:
kubectl delete deployment,service,configmap \
  -n greenfield -l app=oauth2-proxy
```

## Emergency Procedures

### Disable authentication temporarily
```bash
# Delete EnvoyFilter to bypass auth
kubectl delete envoyfilter oauth2-proxy-ext-authz -n istio-system

# Re-enable
kubectl apply -f kustomize/base/auth/base/gateway/envoyfilter-ext-authz.yaml
```

### Allow all users temporarily
```bash
# Create temporary allow-all policy
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: temporary-allow-all
  namespace: greenfield
spec:
  action: ALLOW
  rules:
  - {}
EOF

# Remove when done
kubectl delete authorizationpolicy temporary-allow-all -n greenfield
```

### Reset oauth2-proxy
```bash
# Delete and recreate
kubectl delete deployment oauth2-proxy -n greenfield
kubectl apply -k kustomize/base/auth/overlays/provider-azuread/
```

## Resources

- [Full Documentation](auth-architecture.md)
- [Provider Setup](auth-providers.md)
- [Troubleshooting](auth-troubleshooting.md)
- [App Templates](../../apps/templates/README.md)
- [oauth2-proxy Docs](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
