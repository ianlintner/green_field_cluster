# Authentication Troubleshooting Guide

This guide helps diagnose and fix common authentication issues.

## Quick Diagnostics

Run the auth doctor script first:

```bash
./scripts/auth-doctor.sh
```

This will check:
- Prerequisites (kubectl, Kubernetes connection)
- Namespaces and components
- Secrets and configuration
- Istio integration
- Network connectivity
- OIDC issuer reachability

## Common Issues

### 1. Redirect Loop

**Symptoms:**
- Browser redirects repeatedly between app and IdP
- Never completes authentication
- Cookie not being set

**Causes & Solutions:**

#### Cookie Domain Mismatch
```yaml
# Check cookie domains in ConfigMap
kubectl get configmap oauth2-proxy-config -n greenfield -o yaml

# Cookie domain must match or be parent of app domain
# ✓ Good: cookie-domains: ".example.com" for app at myapp.example.com
# ✗ Bad:  cookie-domains: ".wrong.com" for app at myapp.example.com

# Fix: Update ConfigMap
kubectl edit configmap oauth2-proxy-config -n greenfield
```

#### Redirect URL Mismatch
```bash
# Check redirect URL in oauth2-proxy config
kubectl get configmap oauth2-proxy-config -n greenfield -o jsonpath='{.data.redirect-url}'

# Must match IdP configuration exactly
# Check IdP console for registered redirect URIs
```

#### HTTP vs HTTPS Mismatch
```yaml
# Ensure all URLs use HTTPS in production
data:
  redirect-url: "https://auth.example.com/oauth2/callback"  # ✓
  # NOT: "http://auth.example.com/oauth2/callback"  # ✗
```

#### Missing TLS at Gateway
```bash
# Check if gateway has TLS configured
kubectl get gateway auth-gateway -n istio-system -o yaml

# Ensure TLS mode is SIMPLE and certificate exists
```

### 2. 401 Unauthorized

**Symptoms:**
- Authentication appears to work
- App returns 401 Unauthorized
- JWT validation failing

**Causes & Solutions:**

#### Invalid JWKS URI
```bash
# Check RequestAuthentication
kubectl get requestauthentication -n greenfield -o yaml

# Verify JWKS URI is reachable
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s https://YOUR_ISSUER/.well-known/jwks.json
```

#### Audience Mismatch
```yaml
# JWT audience must match configured audience
spec:
  jwtRules:
  - issuer: "https://issuer.example.com"
    audiences:
    - "your-client-id"  # Must match client ID in JWT token
```

#### Expired Token
```bash
# Check token expiry in logs
kubectl logs -n greenfield -l app=oauth2-proxy | grep -i "token expired"

# Sessions may need refresh
# Check session duration settings in oauth2-proxy
```

#### Clock Skew
```bash
# Check cluster node time sync
for node in $(kubectl get nodes -o name); do
  echo "=== $node ==="
  kubectl debug $node -it --image=busybox -- date
done

# Clock skew > 5 minutes can cause JWT validation failures
# Fix: Ensure NTP is configured on all nodes
```

### 3. 403 Forbidden

**Symptoms:**
- Authentication successful
- Authorization denied
- Blocked by AuthorizationPolicy

**Causes & Solutions:**

#### Group Claim Missing
```bash
# Check if groups claim is in JWT
# Decode JWT token to inspect claims
echo "TOKEN_HERE" | cut -d. -f2 | base64 -d | jq .

# Common issues:
# - Azure AD: Need API permissions for group claims
# - Google: Groups not supported natively
# - GitHub: Teams require org access
```

#### Group Name Mismatch
```yaml
# Check AuthorizationPolicy
kubectl get authorizationpolicy -n greenfield -o yaml

# Group names must match exactly
rules:
- when:
  - key: request.auth.claims[groups]
    values:
    - "developers"  # Must match group name in JWT

# For Azure AD, use group Object ID (GUID)
# For GitHub, use format: "org/team-slug"
```

#### Wrong Claim Key
```yaml
# Different providers use different claim keys
# Azure AD: groups
# Okta: groups
# GitHub: teams (not groups)
# Google: No native groups

# Update policy to use correct claim key
- key: request.auth.claims[teams]  # For GitHub
  values:
  - "myorg/team-admins"
```

### 4. Groups Not in JWT Token

**Symptoms:**
- User authenticated successfully
- Groups claim missing or empty in JWT
- Authorization policies based on groups failing

**Provider-Specific Solutions:**

#### Azure AD
```bash
# 1. App requires API permissions
# In Azure Portal → App Registration → API Permissions
# Add: Microsoft Graph → GroupMember.Read.All
# Grant admin consent

# 2. Configure groups claim in token
# App Registration → Token Configuration
# Add groups claim
# Select: Security groups or All groups

# 3. Verify in oauth2-proxy config
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_OIDC_GROUPS_CLAIM=groups
```

#### Google
```bash
# Google doesn't provide groups in standard OIDC
# Options:
# 1. Use email domain restriction
# 2. Use Google Workspace with service account + Directory API
# 3. Use Keycloak to fetch groups via Google API
```

#### GitHub
```bash
# Ensure org/team permissions
# oauth2-proxy config:
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_GITHUB_ORG=your-org \
  OAUTH2_PROXY_GITHUB_TEAM=team1,team2

# Teams will be in 'teams' claim (not 'groups')
```

#### Okta SAML via Keycloak
```bash
# 1. Configure group attribute in Okta SAML app
# Attribute Statements:
# - Name: groups
# - Value: getFilteredGroups(...)

# 2. Create attribute mapper in Keycloak
# Identity Provider → Mappers → Create
# - Mapper Type: Attribute Importer
# - Attribute Name: groups
# - User Attribute Name: groups

# 3. Create protocol mapper for OIDC client
# Clients → oauth2-proxy → Mappers → Create
# - Mapper Type: User Attribute
# - User Attribute: groups
# - Token Claim Name: groups
# - Claim JSON Type: String
# - Add to ID token: ON
# - Add to access token: ON
```

### 5. oauth2-proxy Not Starting

**Symptoms:**
- Pods in CrashLoopBackOff
- Container fails to start
- Errors in logs

**Causes & Solutions:**

#### Missing Secrets
```bash
# Check if secret exists
kubectl get secret oauth2-proxy-secret -n greenfield

# Verify secret has required keys
kubectl get secret oauth2-proxy-secret -n greenfield -o jsonpath='{.data}' | jq keys

# Should have: client-id, client-secret, cookie-secret

# Create if missing
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

#### Invalid Configuration
```bash
# Check logs for config errors
kubectl logs -n greenfield -l app=oauth2-proxy --tail=100

# Common errors:
# - Invalid issuer URL
# - Malformed redirect URL
# - Invalid cookie secret (must be 16, 24, or 32 bytes)
```

#### Resource Limits
```bash
# Check if OOMKilled
kubectl get pods -n greenfield -l app=oauth2-proxy -o jsonpath='{.items[*].status.containerStatuses[*].lastState.terminated.reason}'

# Increase memory if needed
kubectl set resources deployment/oauth2-proxy -n greenfield \
  --limits=memory=512Mi \
  --requests=memory=256Mi
```

### 6. Keycloak Issues

#### Keycloak Not Starting
```bash
# Check PostgreSQL connection
kubectl logs -n greenfield -l app=keycloak --tail=50 | grep -i postgres

# Verify database secret
kubectl get secret keycloak-db-secret -n greenfield -o yaml

# Check PostgreSQL is running
kubectl get pods -n greenfield -l app=postgres
```

#### SAML Broker Configuration
```bash
# Access Keycloak admin console
kubectl port-forward -n greenfield svc/keycloak 8080:8080

# Common issues:
# 1. SAML certificate not uploaded or expired
# 2. SSO URL mismatch
# 3. Entity ID mismatch
# 4. Attribute mapping not configured

# Check Keycloak logs for SAML errors
kubectl logs -n greenfield -l app=keycloak | grep -i saml
```

### 7. EnvoyFilter Not Working

**Symptoms:**
- Authentication not enforced at gateway
- Requests bypass oauth2-proxy
- No redirect to IdP

**Causes & Solutions:**

#### EnvoyFilter Not Applied
```bash
# Check if EnvoyFilter exists
kubectl get envoyfilter oauth2-proxy-ext-authz -n istio-system

# Verify it's applied to correct gateway
kubectl describe envoyfilter oauth2-proxy-ext-authz -n istio-system

# Check workload selector matches gateway pods
kubectl get pods -n istio-system -l istio=ingressgateway --show-labels
```

#### Wrong Istio Version
```bash
# EnvoyFilter syntax changes between Istio versions
# Check Istio version
istioctl version

# Update EnvoyFilter if needed for your version
# See: https://istio.io/latest/docs/reference/config/networking/envoy-filter/
```

#### OAuth2-proxy Service Not Reachable
```bash
# Test from gateway pod
GATEWAY_POD=$(kubectl get pods -n istio-system -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n istio-system $GATEWAY_POD -- \
  curl -s http://oauth2-proxy.greenfield.svc.cluster.local:4180/ping

# Should return "OK"
```

## Debugging Techniques

### 1. Enable Debug Logging

#### oauth2-proxy
```bash
kubectl set env deployment/oauth2-proxy -n greenfield \
  OAUTH2_PROXY_LOGGING_LEVEL=debug

# View logs
kubectl logs -n greenfield -l app=oauth2-proxy -f
```

#### Istio
```bash
# Enable debug logging for proxy
kubectl port-forward -n greenfield POD_NAME 15000:15000

# In another terminal
curl -X POST http://localhost:15000/logging?level=debug
```

### 2. Inspect JWT Tokens

```bash
# Get token from browser (DevTools → Application → Cookies)
# Or from X-Auth-Request-Access-Token header

# Decode JWT (header.payload.signature)
TOKEN="eyJhbGc..."
echo $TOKEN | cut -d. -f1 | base64 -d | jq .  # Header
echo $TOKEN | cut -d. -f2 | base64 -d | jq .  # Payload

# Check:
# - iss (issuer)
# - aud (audience)
# - exp (expiry)
# - groups/teams claims
```

### 3. Test Authentication Flow Manually

```bash
# 1. Initial request (should redirect)
curl -v https://myapp.example.com/ 2>&1 | grep -i location

# 2. Follow redirect (should go to IdP)
# 3. After auth, check cookie is set
curl -v --cookie-jar cookies.txt https://myapp.example.com/

# 4. Subsequent request with cookie
curl -v --cookie cookies.txt https://myapp.example.com/
```

### 4. Check Istio Policy Evaluation

```bash
# Get envoy logs from sidecar
kubectl logs -n greenfield POD_NAME -c istio-proxy

# Look for authorization decisions
# [external authorization] checking request
# [external authorization] allowed
# [external authorization] denied
```

## Getting Help

If issues persist:

1. **Collect diagnostics**
   ```bash
   ./scripts/auth-doctor.sh > auth-diagnostics.txt
   ```

2. **Gather logs**
   ```bash
   kubectl logs -n greenfield -l app=oauth2-proxy --tail=200 > oauth2-proxy.log
   kubectl logs -n istio-system -l istio=ingressgateway --tail=200 > gateway.log
   ```

3. **Check configuration**
   ```bash
   kubectl get configmap,secret,authorizationpolicy,requestauthentication \
     -n greenfield -o yaml > auth-config.yaml
   ```

4. **Review documentation**
   - oauth2-proxy: https://oauth2-proxy.github.io/oauth2-proxy/
   - Istio Security: https://istio.io/latest/docs/concepts/security/
   - Provider docs (Azure AD, Google, GitHub, Okta)

5. **Open an issue**
   - Include auth-diagnostics.txt
   - Include relevant logs
   - Describe expected vs actual behavior
