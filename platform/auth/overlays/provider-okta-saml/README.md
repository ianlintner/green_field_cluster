# Okta SAML Provider Configuration (via Keycloak Broker)

This overlay configures oauth2-proxy to use Keycloak as an OIDC provider, with Keycloak brokering SAML authentication from Okta.

## Architecture

```
User → oauth2-proxy (OIDC) → Keycloak (OIDC issuer) → Okta (SAML IdP)
```

**Why this architecture?**
- Normalizes SAML to OIDC/JWT for Kubernetes/Istio
- oauth2-proxy and Istio can use standard OIDC flows
- Keycloak handles SAML complexity and attribute mapping
- Enables consistent claim structure across providers

## Prerequisites

### 1. Keycloak Setup
Keycloak will be deployed as part of this overlay. You need:
- PostgreSQL database (already included in greenfield cluster)
- Keycloak admin credentials
- External domain for Keycloak (e.g., `keycloak.example.com`)

### 2. Okta SAML Application
In Okta Admin Console:
1. Create a new SAML 2.0 application
2. Configure SSO URL: `https://keycloak.example.com/auth/realms/master/broker/okta/endpoint`
3. Configure Audience URI (SP Entity ID): `https://keycloak.example.com/auth/realms/master`
4. Note the following from Okta:
   - IdP Issuer URL
   - IdP SSO URL
   - IdP Signing Certificate

### 3. Attribute Statements (in Okta)
Configure these SAML attribute statements:
- `email` → `user.email`
- `firstName` → `user.firstName`
- `lastName` → `user.lastName`
- `groups` → `user.groups` (for group-based authorization)

## Configuration Steps

### 1. Deploy Keycloak and oauth2-proxy

```bash
# Update configmap.yaml with your domain
kubectl apply -k platform/auth/overlays/provider-okta-saml/
```

### 2. Create Secrets

```bash
# Keycloak admin secret
kubectl create secret generic keycloak-admin-secret \
  --from-literal=password=$(openssl rand -base64 32) \
  -n greenfield

# Keycloak database secret
kubectl create secret generic keycloak-db-secret \
  --from-literal=username=keycloak \
  --from-literal=password=$(openssl rand -base64 32) \
  -n greenfield

# oauth2-proxy secret (client will be created in Keycloak)
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=oauth2-proxy \
  --from-literal=client-secret=KEYCLOAK_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

### 3. Configure Keycloak Realm and Okta SAML Broker

After Keycloak is running, configure it via the admin console:

#### Access Keycloak Admin Console
```bash
kubectl port-forward -n greenfield svc/keycloak 8080:8080
# Open http://localhost:8080/auth
# Login with admin credentials
```

#### Create SAML Identity Provider

1. **Go to Identity Providers**
   - Select "SAML v2.0"
   - Alias: `okta`
   - Display Name: `Okta`

2. **Configure SAML Settings**
   - Service Provider Entity ID: `https://keycloak.example.com/auth/realms/master`
   - Single Sign-On Service URL: `https://your-org.okta.com/app/YOUR_APP_ID/sso/saml`
   - Upload Okta's signing certificate

3. **Configure Mappers**
   Create attribute mappers:
   - Email: SAML Attribute `email` → User Property `email`
   - First Name: SAML Attribute `firstName` → User Property `firstName`
   - Last Name: SAML Attribute `lastName` → User Property `lastName`
   - Groups: SAML Attribute `groups` → User Attribute `groups`

4. **Create Group Mapper**
   - Mapper Type: "Attribute to Role"
   - Attribute Name: `groups`
   - Attribute Value: (Okta group name)
   - Role: (Keycloak role name)

#### Create OIDC Client for oauth2-proxy

1. **Go to Clients → Create**
   - Client ID: `oauth2-proxy`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`

2. **Configure Client**
   - Valid Redirect URIs: `https://auth.example.com/oauth2/callback`
   - Base URL: `https://auth.example.com`
   - Web Origins: `https://*.example.com`

3. **Client Scopes**
   - Add `email`, `profile`, `groups` to default scopes

4. **Mappers**
   Create a groups mapper:
   - Mapper Type: "Group Membership"
   - Token Claim Name: `groups`
   - Add to ID token: ON
   - Add to access token: ON
   - Add to userinfo: ON

5. **Get Client Secret**
   - Go to Credentials tab
   - Copy the client secret
   - Update `oauth2-proxy-secret` with this value

### 4. Update ConfigMap with Actual URLs

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
  namespace: greenfield
data:
  oidc-issuer-url: "https://keycloak.example.com/auth/realms/master"
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
```

### 5. Create Istio VirtualService for Keycloak

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: keycloak
  namespace: greenfield
spec:
  hosts:
  - keycloak.example.com
  gateways:
  - istio-system/external-gateway
  http:
  - route:
    - destination:
        host: keycloak
        port:
          number: 8080
```

## Testing

### 1. Test Keycloak Availability
```bash
curl https://keycloak.example.com/auth/realms/master/.well-known/openid-configuration
```

### 2. Test SAML Brokering
```bash
# This should redirect to Okta SAML login
curl -I https://myapp.example.com
```

### 3. Verify JWT Claims
After successful authentication, check the JWT token contains:
- `email`
- `groups`
- `iss`: Keycloak issuer URL
- `aud`: oauth2-proxy client ID

## Group-Based Authorization

With Keycloak brokering, you can map Okta groups to Keycloak roles and use them in Istio policies:

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: group-access
  namespace: greenfield
spec:
  action: ALLOW
  rules:
  - when:
    - key: request.auth.claims[groups]
      values:
      - "/okta-admins"
      - "/okta-developers"
```

## Troubleshooting

### Keycloak Not Starting
- Check PostgreSQL is running
- Verify database secrets are correct
- Check resource limits (Keycloak needs 512Mi+ memory)

### SAML Authentication Fails
- Verify Okta SSO URL is correct
- Check Okta signing certificate is uploaded to Keycloak
- Review Keycloak logs: `kubectl logs -n greenfield -l app=keycloak`

### Groups Not in JWT
- Verify group mapper is configured in Keycloak client
- Check SAML attribute statement for groups in Okta
- Ensure group mapper in Okta SAML IdP config

### Redirect Loops
- Verify cookie domain matches
- Check oauth2-proxy redirect URL matches Keycloak client config
- Ensure HTTPS is properly configured

## Production Considerations

1. **Keycloak High Availability**
   - Increase replicas: `replicas: 3`
   - Use external PostgreSQL with HA
   - Configure shared cache (Infinispan)

2. **Performance**
   - Keycloak can cache SAML assertions
   - Configure session timeouts appropriately
   - Use Keycloak's built-in caching

3. **Security**
   - Rotate client secrets regularly
   - Enable Keycloak security headers
   - Configure brute force detection
   - Enable audit logging

## References

- [Keycloak SAML Brokering](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker_saml)
- [Okta SAML Configuration](https://help.okta.com/en/prod/Content/Topics/Apps/Apps_App_Integration_Wizard_SAML.htm)
- [Keycloak OIDC Clients](https://www.keycloak.org/docs/latest/server_admin/#_oidc_clients)
