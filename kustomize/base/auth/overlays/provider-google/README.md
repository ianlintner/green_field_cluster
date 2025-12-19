# Google Provider Configuration

This overlay configures oauth2-proxy for Google OIDC authentication.

## Prerequisites

1. **Google Cloud Project**
   - Create a project in Google Cloud Console
   - Enable Google+ API (for user info)

2. **OAuth 2.0 Credentials**
   - Go to APIs & Services > Credentials
   - Create OAuth 2.0 Client ID (Web application)
   - Note the Client ID and Client Secret

3. **Configure Redirect URI**
   ```
   https://auth.example.com/oauth2/callback
   ```

## Configuration Steps

### 1. Update Configuration

Edit `configmap.yaml`:
```yaml
data:
  oidc-issuer-url: "https://accounts.google.com"
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
```

### 2. Create Secrets

```bash
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_CLIENT_ID.apps.googleusercontent.com \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

### 3. Deploy

```bash
kubectl apply -k kustomize/base/auth/overlays/provider-google/
```

## Domain Restriction

To restrict access to specific Google Workspace domains:

```bash
# Add to deployment args
- --google-group=your-org.com
# Or use email domain restriction
- --email-domain=your-org.com
```

## Google Group Authorization

For Google Workspace customers to use group-based access:

1. **Create Service Account**
   - Create service account in Google Cloud Console
   - Enable Domain-Wide Delegation
   - Grant necessary OAuth scopes

2. **Configure oauth2-proxy**
   ```yaml
   env:
   - name: OAUTH2_PROXY_GOOGLE_GROUP
     value: "admins@your-org.com"
   - name: OAUTH2_PROXY_GOOGLE_ADMIN_EMAIL
     value: "admin@your-org.com"
   ```

3. **Add Service Account JSON**
   ```bash
   kubectl create secret generic oauth2-proxy-google-sa \
     --from-file=service-account.json=path/to/sa.json \
     -n greenfield
   ```

## Testing

```bash
# Check logs
kubectl logs -n greenfield -l app=oauth2-proxy

# Test authentication
curl -I https://myapp.example.com
# Should redirect to Google login
```

## Troubleshooting

### "Error: redirect_uri_mismatch"
- Verify redirect URI in Google Cloud Console matches exactly
- Must use HTTPS in production

### Domain Restriction Not Working
- Check `--email-domain` or `--google-group` flags
- Verify email claim in JWT token

### Service Account Issues
- Ensure Domain-Wide Delegation is enabled
- Check OAuth scopes granted to service account
- Verify admin email has permissions

## References

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [oauth2-proxy Google Provider](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#google)
