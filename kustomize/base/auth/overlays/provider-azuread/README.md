# Azure AD Provider Configuration

This overlay configures oauth2-proxy for Azure Active Directory (Azure AD) OIDC authentication.

## Prerequisites

1. **Azure AD Application Registration**
   - Create an App Registration in Azure Portal
   - Note the Application (client) ID
   - Note the Directory (tenant) ID
   - Create a client secret

2. **Configure Redirect URI**
   ```
   https://auth.example.com/oauth2/callback
   ```

3. **API Permissions** (optional, for group claims)
   - Add `GroupMember.Read.All` (application permission)
   - Grant admin consent

## Configuration Steps

### 1. Update Configuration

Edit `configmap.yaml`:
```yaml
data:
  oidc-issuer-url: "https://login.microsoftonline.com/YOUR_TENANT_ID/v2.0"
  azure-tenant: "YOUR_TENANT_ID"
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
```

### 2. Create Secrets

Using kubectl:
```bash
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

Using sealed-secrets:
```bash
# Create secret template
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml
```

### 3. Deploy

```bash
kubectl apply -k kustomize/base/auth/overlays/provider-azuread/
```

## Group-Based Authorization

To enable group-based authorization with Azure AD:

1. **Configure Group Claims in Azure AD**
   - In App Registration, go to Token Configuration
   - Add groups claim
   - Select "Security groups" or "Groups assigned to the application"

2. **Update Deployment**
   ```yaml
   env:
   - name: OAUTH2_PROXY_ALLOWED_GROUPS
     value: "12345678-1234-1234-1234-123456789012"  # Azure AD group Object ID
   ```

3. **Update Authorization Policy**
   ```yaml
   rules:
   - when:
     - key: request.auth.claims[groups]
       values:
       - "12345678-1234-1234-1234-123456789012"
   ```

## Testing

1. **Check oauth2-proxy logs**
   ```bash
   kubectl logs -n greenfield -l app=oauth2-proxy
   ```

2. **Test authentication flow**
   ```bash
   curl -I https://myapp.example.com
   # Should redirect to Azure AD login
   ```

3. **Verify JWT token**
   After authentication, check headers:
   ```
   X-Auth-Request-User: user@example.com
   X-Auth-Request-Email: user@example.com
   X-Auth-Request-Access-Token: eyJ...
   ```

## Troubleshooting

### Redirect Loop
- Verify cookie domain matches your domain
- Check that redirect URL is registered in Azure AD
- Ensure HTTPS is properly configured

### Group Claims Not Working
- Verify API permissions are granted
- Check token configuration in Azure AD
- Ensure app has GroupMember.Read.All permission

### JWT Validation Fails
- Verify issuer URL matches Azure AD tenant
- Check that audience (client ID) is correct
- Ensure clock sync between cluster nodes

## References

- [Azure AD OAuth 2.0 Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [oauth2-proxy Azure Provider](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#azure)
- [Azure AD Token Claims](https://docs.microsoft.com/en-us/azure/active-directory/develop/access-tokens)
