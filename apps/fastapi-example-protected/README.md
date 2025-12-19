# Example: Protected FastAPI Application

This example shows how to protect the existing FastAPI application with authentication.

## Configuration

The FastAPI app is protected using:
- Azure AD as the identity provider
- Group-based authorization (developers group)
- Public health and metrics endpoints

## Files

- `auth.yaml` - Authentication configuration
- `kustomization.yaml` - Kustomize overlay

## Apply Protection

```bash
# Using automation script
./scripts/auth-protect.sh fastapi-app fastapi.example.com "group:developers"

# Or manually
kubectl apply -f apps/fastapi-example-protected/auth.yaml
```

## Test Authentication

```bash
# Should redirect to Azure AD login
curl -I https://fastapi.example.com/

# Health check should work without auth
curl https://fastapi.example.com/health
```

## Verify

```bash
# Check policies
kubectl get authorizationpolicy,requestauthentication -n greenfield -l app=fastapi-app

# View oauth2-proxy logs
kubectl logs -n greenfield -l app=oauth2-proxy -f
```
