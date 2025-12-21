# Ingress URLs Configuration

This guide explains how to configure ingress URLs for your Greenfield Cluster using Istio Gateway and cert-manager for TLS certificate management.

## Overview

The Greenfield Cluster uses Istio as the service mesh and ingress gateway. While DNS management is handled externally, this guide shows you how to:

- Configure Istio Gateway resources to route traffic based on hostnames
- Set up TLS certificates using cert-manager and Let's Encrypt
- Configure both wildcard certificates and individual service certificates
- Route traffic to services using VirtualService resources

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    External DNS                              │
│   *.example.com  →  LoadBalancer IP (Istio Ingress)        │
│   example.com    →  LoadBalancer IP (Istio Ingress)        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│         Istio External Ingress Gateway (LoadBalancer)        │
│  - Terminates TLS using cert-manager certificates           │
│  - Routes based on Host header                               │
│  - Ports: 80 (HTTP), 443 (HTTPS)                            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
    ┌───────────▼─────────┐ ┌──────────▼────────────┐
    │  Wildcard Gateway   │ │ Service-specific      │
    │  *.example.com      │ │ Gateways              │
    │  (wildcard cert)    │ │ (individual certs)    │
    └───────────┬─────────┘ └──────────┬────────────┘
                │                       │
                └───────────┬───────────┘
                            │
                ┌───────────▼───────────┐
                │  VirtualServices      │
                │  - app.example.com    │
                │  - api.example.com    │
                │  - grafana.example.com│
                └───────────┬───────────┘
                            │
                ┌───────────▼───────────┐
                │  Backend Services     │
                │  - FastAPI            │
                │  - Grafana            │
                │  - Custom Apps        │
                └───────────────────────┘
```

## Prerequisites

1. **Kubernetes cluster** with Greenfield Cluster deployed
2. **Istio** installed and configured (included in Greenfield)
3. **cert-manager** installed and configured (included in Greenfield)
4. **DNS records** pointing to your Istio ingress gateway's LoadBalancer IP
5. **Domain name** that you control

## DNS Setup

Before configuring ingress, you need to point your domain's DNS records to your cluster's ingress IP address.

### Get Your Ingress IP Address

```bash
# Get the external IP of the Istio ingress gateway
kubectl get svc istio-ingressgateway -n istio-system

# Or use this to get just the IP
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Your ingress IP: $INGRESS_IP"
```

### DNS Records Required

For a domain like `greenfieldcluster.example` with services, you'll need:

```
# Required DNS A records:
greenfieldcluster.example.        A    <INGRESS_IP>
*.greenfieldcluster.example.      A    <INGRESS_IP>
```

This configuration allows:
- `greenfieldcluster.example` - Root domain traffic
- `app.greenfieldcluster.example` - Service subdomains
- `api.greenfieldcluster.example` - API subdomains
- Any other `*.greenfieldcluster.example` subdomain

### Platform-Specific DNS Configuration

See the detailed DNS configuration guides for your cloud provider:

- [AWS Route 53 Configuration](./dns-aws.md)
- [Azure DNS Configuration](./dns-azure.md)
- [Google Cloud DNS Configuration](./dns-gcp.md)

## Certificate Configuration

The Greenfield Cluster uses cert-manager to automatically obtain and renew TLS certificates from Let's Encrypt.

### Option 1: Wildcard Certificate (Recommended for Multiple Subdomains)

A wildcard certificate covers all subdomains under your domain.

**Benefits:**
- Single certificate for all `*.example.com` subdomains
- Simpler management
- Fewer certificate renewals

**Limitations:**
- Requires DNS-01 challenge (DNS provider integration)
- More complex initial setup

**Note:** Wildcard certificates require DNS-01 challenge, which needs DNS provider API integration. This is beyond the basic HTTP-01 challenge and requires additional configuration.

For HTTP-01 challenge (simpler but no wildcards), see Option 2 below.

### Option 2: Individual Certificates (Simpler Setup)

Issue separate certificates for each service domain.

**Benefits:**
- Uses HTTP-01 challenge (simpler, no DNS API needed)
- Works immediately with the cluster setup
- Better isolation (compromised cert doesn't affect all services)

**Limitations:**
- One certificate per domain/subdomain
- More certificates to manage

**Example: Certificate for a specific service**

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-example-cert
  namespace: istio-system
spec:
  secretName: app-example-tls
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days before expiry
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.greenfieldcluster.example
```

### Using Staging vs Production Issuers

**Always test with staging first!**

```yaml
# For testing - uses letsencrypt-staging
issuerRef:
  name: letsencrypt-staging
  kind: ClusterIssuer
```

Let's Encrypt production has rate limits (50 certificates per domain per week). Test with staging first, then switch to production:

```yaml
# For production - uses letsencrypt-prod
issuerRef:
  name: letsencrypt-prod
  kind: ClusterIssuer
```

## Gateway Configuration

Istio Gateway resources define how external traffic enters the cluster.

### Basic Gateway with Single Certificate

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: app-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  # HTTP server for ACME challenges and redirect
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "app.greenfieldcluster.example"
    tls:
      httpsRedirect: true  # Redirect HTTP to HTTPS
  # HTTPS server with TLS
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: app-example-tls  # Certificate secret name
    hosts:
    - "app.greenfieldcluster.example"
```

### Gateway with Multiple Certificates

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: services-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  # HTTP for all services
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.greenfieldcluster.example"
    tls:
      httpsRedirect: true
  # HTTPS for app service
  - port:
      number: 443
      name: https-app
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: app-example-tls
    hosts:
    - "app.greenfieldcluster.example"
  # HTTPS for api service
  - port:
      number: 443
      name: https-api
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: api-example-tls
    hosts:
    - "api.greenfieldcluster.example"
  # HTTPS for monitoring
  - port:
      number: 443
      name: https-grafana
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: grafana-example-tls
    hosts:
    - "grafana.greenfieldcluster.example"
```

### Gateway with Wildcard Certificate

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: wildcard-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.greenfieldcluster.example"
    - "greenfieldcluster.example"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: wildcard-example-tls  # Wildcard certificate
    hosts:
    - "*.greenfieldcluster.example"
    - "greenfieldcluster.example"
```

## VirtualService Configuration

VirtualService resources route traffic from the Gateway to backend services.

### Basic VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app-service
  namespace: greenfield
spec:
  hosts:
  - "app.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: fastapi-app.greenfield.svc.cluster.local
        port:
          number: 8000
```

### VirtualService with Path-Based Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service
  namespace: greenfield
spec:
  hosts:
  - "api.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  # API v1 routes
  - match:
    - uri:
        prefix: /v1/
    route:
    - destination:
        host: api-v1.greenfield.svc.cluster.local
        port:
          number: 8000
  # API v2 routes
  - match:
    - uri:
        prefix: /v2/
    route:
    - destination:
        host: api-v2.greenfield.svc.cluster.local
        port:
          number: 8000
  # Default route
  - route:
    - destination:
        host: api-v2.greenfield.svc.cluster.local
        port:
          number: 8000
```

### VirtualService with Header-Based Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: canary-service
  namespace: greenfield
spec:
  hosts:
  - "app.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  # Route canary traffic (10%)
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: app-canary.greenfield.svc.cluster.local
        port:
          number: 8000
  # Route production traffic (90%)
  - route:
    - destination:
        host: app-prod.greenfield.svc.cluster.local
        port:
          number: 8000
      weight: 90
    - destination:
        host: app-canary.greenfield.svc.cluster.local
        port:
          number: 8000
      weight: 10
```

## Complete Example: Deploying a Service with Ingress

Here's a complete example deploying a service with ingress access:

### 1. Create the Certificate

```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-cert
  namespace: istio-system
spec:
  secretName: myapp-tls
  duration: 2160h
  renewBefore: 360h
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.greenfieldcluster.example
```

Apply it:
```bash
kubectl apply -f certificate.yaml
```

### 2. Wait for Certificate Issuance

```bash
# Check certificate status
kubectl get certificate -n istio-system myapp-cert

# Should show READY=True
# NAME         READY   SECRET       AGE
# myapp-cert   True    myapp-tls    2m
```

### 3. Create or Update Gateway

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: myapp-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.greenfieldcluster.example"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: myapp-tls
    hosts:
    - "myapp.greenfieldcluster.example"
```

Apply it:
```bash
kubectl apply -f gateway.yaml
```

### 4. Create VirtualService

```yaml
# virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
  namespace: greenfield
spec:
  hosts:
  - "myapp.greenfieldcluster.example"
  gateways:
  - istio-system/myapp-gateway
  http:
  - route:
    - destination:
        host: myapp-service.greenfield.svc.cluster.local
        port:
          number: 8000
```

Apply it:
```bash
kubectl apply -f virtualservice.yaml
```

### 5. Verify the Setup

```bash
# Check gateway
kubectl get gateway -n istio-system myapp-gateway

# Check virtualservice
kubectl get virtualservice -n greenfield myapp

# Test the endpoint
curl https://myapp.greenfieldcluster.example

# Or with verbose output
curl -v https://myapp.greenfieldcluster.example
```

## Multiple Services Example

Here's how to configure multiple services on the same domain:

```yaml
---
# Multiple certificates
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-cert
  namespace: istio-system
spec:
  secretName: app-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - app.greenfieldcluster.example
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-cert
  namespace: istio-system
spec:
  secretName: api-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - api.greenfieldcluster.example
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: grafana-cert
  namespace: istio-system
spec:
  secretName: grafana-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - grafana.greenfieldcluster.example
---
# Single gateway with multiple TLS configurations
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: services-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.greenfieldcluster.example"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https-app
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: app-tls
    hosts:
    - "app.greenfieldcluster.example"
  - port:
      number: 443
      name: https-api
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: api-tls
    hosts:
    - "api.greenfieldcluster.example"
  - port:
      number: 443
      name: https-grafana
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: grafana-tls
    hosts:
    - "grafana.greenfieldcluster.example"
---
# VirtualServices for each service
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app
  namespace: greenfield
spec:
  hosts:
  - "app.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  - route:
    - destination:
        host: fastapi-app.greenfield.svc.cluster.local
        port:
          number: 8000
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api
  namespace: greenfield
spec:
  hosts:
  - "api.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  - route:
    - destination:
        host: fastapi-app.greenfield.svc.cluster.local
        port:
          number: 8000
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: grafana
  namespace: greenfield
spec:
  hosts:
  - "grafana.greenfieldcluster.example"
  gateways:
  - istio-system/services-gateway
  http:
  - route:
    - destination:
        host: grafana.greenfield.svc.cluster.local
        port:
          number: 3000
```

## Troubleshooting

### Certificate Not Issued

```bash
# Check certificate status
kubectl describe certificate -n istio-system myapp-cert

# Check certificate request
kubectl get certificaterequest -n istio-system
kubectl describe certificaterequest -n istio-system

# Check ACME challenge
kubectl get challenge -n istio-system
kubectl describe challenge -n istio-system
```

**Common issues:**
- DNS not pointing to ingress IP
- Port 80 not accessible (needed for HTTP-01 challenge)
- Rate limit hit (use staging issuer first)

### Gateway Not Working

```bash
# Check gateway status
kubectl get gateway -n istio-system
kubectl describe gateway -n istio-system myapp-gateway

# Check ingress gateway logs
kubectl logs -n istio-system -l istio=ingressgateway --tail=100
```

### VirtualService Not Routing

```bash
# Check virtualservice
kubectl get virtualservice -n greenfield
kubectl describe virtualservice -n greenfield myapp

# Test with curl
curl -v https://myapp.greenfieldcluster.example

# Check if service exists
kubectl get svc -n greenfield
```

### Certificate Secret Not Found

Make sure the certificate is ready and the secret exists:

```bash
# Check certificate
kubectl get certificate -n istio-system myapp-cert

# Check secret
kubectl get secret -n istio-system myapp-tls

# If secret is missing, check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

## Best Practices

1. **Start with Staging Certificates**: Always test with `letsencrypt-staging` before using `letsencrypt-prod`

2. **Use Wildcard for Multiple Subdomains**: If you have many services, wildcard certificates simplify management (requires DNS-01)

3. **Individual Certs for Security**: For production, consider individual certificates for better isolation

4. **HTTP to HTTPS Redirect**: Always enable `httpsRedirect: true` for security

5. **Certificate Duration**: Standard 90-day duration with 15-day renewal window is recommended

6. **Namespace Organization**:
   - Certificates in `istio-system` (where Gateway reads them)
   - Gateways in `istio-system`
   - VirtualServices with their services

7. **Monitor Certificate Expiry**: cert-manager handles renewal automatically, but monitor for issues

8. **DNS TTL**: Use low TTL values (300-600s) when initially setting up to allow quick changes

## Security Considerations

1. **TLS Version**: Istio uses TLS 1.2+ by default
2. **Certificate Authority**: Let's Encrypt is trusted by all major browsers
3. **Private Keys**: Stored as Kubernetes secrets, ensure RBAC is properly configured
4. **mTLS**: Internal service-to-service communication uses Istio's automatic mTLS
5. **Rate Limiting**: Implement rate limiting at the VirtualService level if needed

## Additional Resources

- [Istio Gateway Documentation](../components/istio.md)
- [cert-manager Documentation](../components/cert-manager.md)
- [DNS Configuration Guides](./dns-aws.md)
- [Official Istio Traffic Management](https://istio.io/latest/docs/tasks/traffic-management/)
- [cert-manager Tutorials](https://cert-manager.io/docs/tutorials/)
