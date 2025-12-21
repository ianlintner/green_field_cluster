# cert-manager

cert-manager is a Kubernetes add-on that automates the management and issuance of TLS certificates from various certificate authorities (CAs), including Let's Encrypt.

## Overview

The greenfield cluster includes cert-manager configuration for:
- **Automated certificate issuance** from Let's Encrypt
- **Automatic certificate renewal** before expiration
- **Support for HTTP-01 challenges** via Istio ingress
- **Both staging and production** Let's Encrypt environments

**📖 For complete ingress configuration with cert-manager, see the [Ingress URLs Configuration Guide](../networking/ingress-configuration.md).**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / Clients                        │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS (443)
                            │
┌───────────────────────────▼─────────────────────────────────┐
│              Istio External Ingress Gateway                  │
│                   (LoadBalancer)                             │
│          Uses TLS certificate from Secret                    │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Istio Gateway                             │
│              references credentialName                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                  cert-manager                                │
│  ┌────────────────────────────────────────────────────┐     │
│  │ Certificate Resource                               │     │
│  │  - Requests certificate for domain                 │     │
│  │  - Specifies ClusterIssuer to use                  │     │
│  │  - Defines renewal parameters                      │     │
│  └────────────────┬───────────────────────────────────┘     │
│                   │                                          │
│  ┌────────────────▼───────────────────────────────────┐     │
│  │ ClusterIssuer                                      │     │
│  │  - letsencrypt-staging (for testing)               │     │
│  │  - letsencrypt-prod (for production)               │     │
│  └────────────────┬───────────────────────────────────┘     │
└───────────────────┼──────────────────────────────────────────┘
                    │
                    │ ACME Protocol
                    │
┌───────────────────▼─────────────────────────────────────────┐
│              Let's Encrypt CA                                │
│  - Validates domain ownership (HTTP-01 challenge)            │
│  - Issues signed certificate                                 │
└──────────────────────────────────────────────────────────────┘
```

## Features

### Automated Certificate Management
- **Automatic issuance**: Request certificates by creating Certificate resources
- **Auto-renewal**: Certificates are automatically renewed before expiration
- **Multiple issuers**: Support for staging and production Let's Encrypt

### HTTP-01 Challenge
The configuration uses HTTP-01 challenge for domain validation:
- Let's Encrypt sends a challenge to verify domain ownership
- Challenge is served via the Istio ingress gateway
- Works for any publicly accessible domain

### Certificate Storage
- Certificates stored as Kubernetes Secrets
- Secrets automatically updated on renewal
- Referenced by Istio Gateway resources

## Installation

### Prerequisites
- Kubernetes cluster (v1.24+)
- kubectl configured
- Public domain with DNS pointing to cluster

### Install cert-manager

#### Using kubectl:
```bash
# Install cert-manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

#### Using Helm:
```bash
# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true
```

### Install ClusterIssuers

After cert-manager is installed:
```bash
kubectl apply -k kustomize/base/cert-manager/
```

This creates:
- `letsencrypt-staging`: For testing (avoids rate limits)
- `letsencrypt-prod`: For production certificates

## Usage

### Basic Certificate Request

Create a Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
  namespace: istio-system
spec:
  secretName: myapp-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

### Use with Istio Gateway

Reference the certificate secret in your Gateway:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: myapp-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-tls  # References the Certificate secret
    hosts:
    - myapp.example.com
```

### Complete Example

See the [Istio documentation](../istio.md) for complete examples including:
- Gateway configuration
- VirtualService routing
- Certificate requests

## Configuration

### Email Address

**Important**: Update the email address in ClusterIssuer configurations:

```yaml
# Edit kustomize/base/cert-manager/cluster-issuer-letsencrypt-prod.yaml
spec:
  acme:
    email: your-email@example.com  # Change this!
```

The email is used for:
- Certificate expiration notifications
- Account recovery
- Important updates from Let's Encrypt

### Staging vs Production

#### Staging Issuer (`letsencrypt-staging`)
- **Use for**: Development and testing
- **Benefits**: No rate limits
- **Drawback**: Certificates not trusted by browsers
- **Server**: https://acme-staging-v02.api.letsencrypt.org/directory

#### Production Issuer (`letsencrypt-prod`)
- **Use for**: Production deployments
- **Benefits**: Trusted certificates
- **Rate Limits**: 50 certificates per registered domain per week
- **Server**: https://acme-v02.api.letsencrypt.org/directory

**Best Practice**: Always test with staging issuer first!

## Verification

### Check cert-manager Status

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Should show:
# NAME                                      READY   STATUS    RESTARTS   AGE
# cert-manager-xxxxx-xxxxx                  1/1     Running   0          5m
# cert-manager-cainjector-xxxxx-xxxxx       1/1     Running   0          5m
# cert-manager-webhook-xxxxx-xxxxx          1/1     Running   0          5m
```

### Check ClusterIssuers

```bash
kubectl get clusterissuer

# Should show:
# NAME                     READY   AGE
# letsencrypt-prod         True    5m
# letsencrypt-staging      True    5m
```

### Check Certificates

```bash
# List all certificates
kubectl get certificate -A

# Describe a specific certificate
kubectl describe certificate myapp-cert -n istio-system

# Check the certificate secret
kubectl get secret myapp-tls -n istio-system
```

### Certificate Status

A successful certificate will show:
```bash
kubectl get certificate myapp-cert -n istio-system

# NAME          READY   SECRET       AGE
# myapp-cert    True    myapp-tls    2m
```

## Troubleshooting

### Certificate Not Issued

1. Check Certificate status:
```bash
kubectl describe certificate myapp-cert -n istio-system
```

2. Check CertificateRequest:
```bash
kubectl get certificaterequest -n istio-system
kubectl describe certificaterequest -n istio-system
```

3. Check Order and Challenge:
```bash
kubectl get order -n istio-system
kubectl describe order -n istio-system

kubectl get challenge -n istio-system
kubectl describe challenge -n istio-system
```

### Common Issues

#### Domain Not Accessible
**Problem**: HTTP-01 challenge fails because domain is not accessible

**Solution**:
- Verify DNS points to your LoadBalancer IP
- Ensure port 80 is accessible
- Check firewall rules

```bash
# Get LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system

# Test domain accessibility
curl -v http://myapp.example.com/.well-known/acme-challenge/test
```

#### Rate Limit Exceeded
**Problem**: Hit Let's Encrypt rate limits (50 certs/domain/week)

**Solution**:
- Use staging issuer for testing
- Wait for rate limit to reset (weekly)
- Consider using wildcard certificates

#### Wrong Email
**Problem**: Email address not updated in ClusterIssuer

**Solution**:
```bash
# Edit ClusterIssuer
kubectl edit clusterissuer letsencrypt-prod

# Update email field, save and exit
```

### View Logs

```bash
# cert-manager controller logs
kubectl logs -n cert-manager deployment/cert-manager

# cert-manager webhook logs
kubectl logs -n cert-manager deployment/cert-manager-webhook

# Follow logs in real-time
kubectl logs -n cert-manager deployment/cert-manager -f
```

## Best Practices

### Development Workflow

1. **Start with staging**:
   ```yaml
   issuerRef:
     name: letsencrypt-staging
   ```

2. **Verify certificate works**:
   - Check certificate is issued
   - Test HTTPS connection (ignore browser warning)
   - Verify auto-renewal

3. **Switch to production**:
   ```yaml
   issuerRef:
     name: letsencrypt-prod
   ```

### Certificate Organization

- **Namespace**: Store certificates in `istio-system` namespace for Istio Gateway use
- **Naming**: Use descriptive names (`myapp-prod-cert`, `myapp-staging-cert`)
- **Documentation**: Document which certificates are used by which services

### Security

- **Separate certificates**: Use different certificates for different environments
- **Regular rotation**: cert-manager handles this automatically
- **Monitor expiration**: Set up alerts for certificate expiration (cert-manager handles renewal automatically)

### Wildcard Certificates

For multiple subdomains, use wildcard certificates:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-cert
  namespace: istio-system
spec:
  secretName: wildcard-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - "*.example.com"
  - example.com
```

**Note**: Wildcard certificates require DNS-01 challenge, which needs additional DNS provider configuration.

## Resources

- [Ingress URLs Configuration Guide](../networking/ingress-configuration.md) - Complete guide with cert-manager examples
- [DNS Configuration Guides](../networking/dns-aws.md) - DNS setup for AWS, Azure, and GCP
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Istio TLS Documentation](https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/)

## Support

For issues:
1. Check the troubleshooting section above
2. Review cert-manager logs
3. Consult cert-manager documentation
4. Open an issue in the repository
