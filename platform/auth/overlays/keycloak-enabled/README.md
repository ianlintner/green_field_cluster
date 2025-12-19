# Keycloak as Primary IdP

This overlay deploys Keycloak as the primary identity provider for the cluster.

## Use Cases

- Platform-owned identity management
- Service account management
- Complex realm and client configurations
- Federation to multiple external IdPs
- Custom authentication flows

## Configuration

### Deploy Keycloak

```bash
kubectl apply -k platform/auth/overlays/keycloak-enabled/
```

### Access Keycloak Admin Console

```bash
kubectl port-forward -n greenfield svc/keycloak 8080:8080
# Open http://localhost:8080/auth
```

### Configure Realms and Clients

Use the Keycloak admin console or REST API to:
1. Create application-specific realms
2. Configure OIDC clients for each protected app
3. Set up user federation (LDAP, Active Directory, etc.)
4. Configure identity brokering to external providers

## Integration with oauth2-proxy

Update oauth2-proxy configuration to use Keycloak:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
data:
  oidc-issuer-url: "https://keycloak.example.com/auth/realms/YOUR_REALM"
```

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak on Kubernetes](https://www.keycloak.org/getting-started/getting-started-kube)
