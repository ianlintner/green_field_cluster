# GitHub Provider Configuration

This overlay configures oauth2-proxy for GitHub OAuth authentication.

## Prerequisites

1. **GitHub OAuth App**
   - Go to Settings > Developer settings > OAuth Apps
   - Create a new OAuth App
   - Note the Client ID and Client Secret

2. **Configure Authorization Callback URL**
   ```
   https://auth.example.com/oauth2/callback
   ```

## Configuration Steps

### 1. Update Configuration

Edit `configmap.yaml`:
```yaml
data:
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
  github-org: "your-org"  # Optional: restrict to org
  github-team: "your-team"  # Optional: restrict to team
```

### 2. Create Secrets

```bash
kubectl create secret generic oauth2-proxy-secret \
  --from-literal=client-id=YOUR_GITHUB_CLIENT_ID \
  --from-literal=client-secret=YOUR_GITHUB_CLIENT_SECRET \
  --from-literal=cookie-secret=$(openssl rand -base64 32 | head -c 32) \
  -n greenfield
```

### 3. Deploy

```bash
kubectl apply -k kustomize/base/auth/overlays/provider-github/
```

## Organization/Team Restriction

To restrict access to specific GitHub organizations or teams:

### Organization Only
```yaml
env:
- name: OAUTH2_PROXY_GITHUB_ORG
  value: "your-organization"
```

### Organization + Team
```yaml
env:
- name: OAUTH2_PROXY_GITHUB_ORG
  value: "your-organization"
- name: OAUTH2_PROXY_GITHUB_TEAM
  value: "your-team,another-team"
```

### Multiple Organizations
```yaml
env:
- name: OAUTH2_PROXY_GITHUB_ORG
  value: "org1,org2,org3"
```

## Team-Based Authorization

For fine-grained team-based access control:

1. **Configure Multiple Teams**
   ```bash
   - --github-team=org/team-admins
   - --github-team=org/team-developers
   ```

2. **Map to Authorization Policies**
   GitHub team slugs will be available in claims for Istio policies:
   ```yaml
   rules:
   - when:
     - key: request.auth.claims[teams]
       values:
       - "org/team-admins"
       - "org/team-developers"
   ```

## OAuth App Scopes

The OAuth app requires the following scopes:
- `user:email` - Read user email addresses (required)
- `read:org` - Read organization membership (for org restriction)
- `read:team` - Read team membership (for team restriction)

## Testing

```bash
# Check logs
kubectl logs -n greenfield -l app=oauth2-proxy

# Test authentication
curl -I https://myapp.example.com
# Should redirect to GitHub login
```

## Troubleshooting

### "Error: redirect_uri_mismatch"
- Verify Authorization callback URL in GitHub OAuth App
- Must match exactly including protocol and path

### Organization Restriction Not Working
- Verify user is member of specified organization
- Check organization visibility (user must be a public or private member)
- Review oauth2-proxy logs for authorization errors

### Team Access Issues
- Ensure user is member of specified team
- Verify OAuth app has `read:org` scope
- Check team slug format: `organization/team-slug`

### Private Organization Members
- User must grant permission to access private org membership
- Organization admin can enable OAuth app access

## References

- [GitHub OAuth Documentation](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [oauth2-proxy GitHub Provider](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#github)
- [GitHub API Scopes](https://docs.github.com/en/developers/apps/building-oauth-apps/scopes-for-oauth-apps)
