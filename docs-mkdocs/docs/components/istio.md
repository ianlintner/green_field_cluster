# Istio

Istio is a service mesh that provides traffic management, security, and observability for microservices. This greenfield cluster includes Istio configuration with SSL/TLS ingress support.

## Overview

The cluster includes Istio configuration with:
- **External ingress gateway**: For public-facing services with SSL/TLS termination
- **Internal ingress gateway**: For cluster-internal services
- **Gateway resources**: Pre-configured for HTTP and HTTPS traffic
- **Integration with cert-manager**: For automated certificate management

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / Clients                        │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS (443) / HTTP (80)
                            │
┌───────────────────────────▼─────────────────────────────────┐
│         Istio External Ingress Gateway (LoadBalancer)        │
│  - TLS Termination                                           │
│  - Load Balancing                                            │
│  - Traffic Routing                                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
┌─────────────▼───────────┐   ┌──────────▼────────────┐
│  External Gateway       │   │  Internal Gateway     │
│  - Public services      │   │  - Internal services  │
│  - HTTPS with TLS       │   │  - mTLS               │
└─────────────┬───────────┘   └──────────┬────────────┘
              │                           │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   VirtualService          │
              │   - Route to services     │
              │   - Path-based routing    │
              │   - Host-based routing    │
              └─────────────┬─────────────┘
                            │
              ┌─────────────▼─────────────┐
              │   Application Services     │
              │   - FastAPI               │
              │   - Grafana               │
              │   - Prometheus            │
              └───────────────────────────┘
```

## Components

### Ingress Gateways

#### External Gateway (`istio-ingressgateway`)
- **Type**: LoadBalancer
- **Purpose**: Public-facing services with SSL/TLS termination
- **Ports**: 
  - 80 (HTTP) - For ACME challenges and optional redirect to HTTPS
  - 443 (HTTPS) - For secure traffic with TLS termination
- **Selector**: `istio: ingressgateway`, `gateway-type: external`
- **Configuration**: `kustomize/base/istio/istio-config.yaml`

#### Internal Gateway (`istio-ingressgateway-internal`)
- **Type**: ClusterIP
- **Purpose**: Internal services within the cluster
- **Ports**: 
  - 80 (HTTP) - For internal HTTP traffic
  - 443 (HTTPS) - For internal HTTPS with mTLS
- **Selector**: `istio: ingressgateway-internal`, `gateway-type: internal`
- **Configuration**: `kustomize/base/istio/istio-config.yaml`

### Gateway Resources

#### External Gateway Resource
Handles public HTTPS traffic:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: external-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
    gateway-type: external
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: example-tls  # cert-manager certificate
    hosts:
    - "example.com"
```

#### Internal Gateway Resource
Handles internal traffic with mTLS:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: internal-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway-internal
    gateway-type: internal
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: MUTUAL
      credentialName: internal-tls
    hosts:
    - "*.internal"
```

## Installation

See the [Istio installation guide](../../kustomize/base/istio/README.md) in the kustomize directory.

### Quick Start

Using Helm:
```bash
# Add Istio repository
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install Istio base
helm install istio-base istio/base -n istio-system --create-namespace

# Install Istiod
helm install istiod istio/istiod -n istio-system --wait
```

Then apply the cluster configuration:
```bash
# Apply Istio configuration (creates ingress gateways)
kubectl apply -f kustomize/base/istio/istio-config.yaml

# Apply Gateway resources
kubectl apply -f kustomize/base/istio/gateways.yaml
```

## SSL/TLS Configuration

### Prerequisites
1. Install cert-manager (see [cert-manager documentation](./cert-manager.md))
2. Configure DNS to point to LoadBalancer IP
3. Create Certificate resources

### Certificate Request

Create a Certificate for your domain:
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

### Gateway with TLS

Reference the certificate in your Gateway:
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
      credentialName: myapp-tls  # From Certificate resource
    hosts:
    - myapp.example.com
```

### VirtualService

Route traffic to your service:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
  namespace: greenfield
spec:
  hosts:
  - myapp.example.com
  gateways:
  - istio-system/myapp-gateway
  http:
  - route:
    - destination:
        host: myapp-service.greenfield.svc.cluster.local
        port:
          number: 8000
```

## Mutual TLS (mTLS)

This cluster has STRICT mTLS enabled for all service-to-service communication, providing:
- **Encryption in transit** - All traffic between services is encrypted
- **Mutual authentication** - Both client and server verify each other's identity
- **Zero application changes** - Istio sidecars handle everything transparently
- **Automatic certificate management** - Istio manages certificate rotation

### Current Configuration

**Automatic Sidecar Injection:**
The `greenfield` namespace has the `istio-injection: enabled` label, which automatically injects Istio sidecars into all pods.

```bash
# Verify namespace label
kubectl get namespace greenfield -o yaml | grep istio-injection
# Output: istio-injection: enabled
```

**PeerAuthentication Policies:**
STRICT mTLS is enforced in both `greenfield` and `istio-system` namespaces:

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: greenfield
spec:
  mtls:
    mode: STRICT
```

**DestinationRules:**
Client-side mTLS traffic policies are configured:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default-mtls
  namespace: greenfield
spec:
  host: "*.greenfield.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
```

### Workloads with mTLS

All workloads in the `greenfield` namespace automatically get Istio sidecars and use mTLS:

**Applications:**
- FastAPI app (2 replicas)
- Jaeger (1 replica)
- OTel Collector (2 replicas)
- Grafana (1 replica)
- Prometheus (1 replica)

**Databases:**
- MySQL (3 replicas)
- PostgreSQL (3 replicas)
- MongoDB (3 replicas)
- Redis Master + Replicas (3 replicas total)
- Kafka + Zookeeper (6 replicas total)

### Verify mTLS

```bash
# Check PeerAuthentication policies
kubectl get peerauthentication -A

# Check DestinationRules
kubectl get destinationrule -A

# Verify a pod has Istio sidecar
kubectl get pod <pod-name> -n greenfield -o jsonpath='{.spec.containers[*].name}'
# Should show: <app-container> istio-proxy

# Check mTLS status for a service (requires istioctl)
istioctl authn tls-check <pod-name>.greenfield <service>.greenfield.svc.cluster.local
```

### Disabling Injection (if needed)

To disable sidecar injection for a specific workload:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"
```

## Examples

The configuration includes example files:
- `virtualservices-example.yaml`: Example routing configurations
- `certificates-example.yaml`: Example certificate requests

To use:
```bash
# Update with your domain names
kubectl apply -f kustomize/base/istio/certificates-example.yaml
kubectl apply -f kustomize/base/istio/virtualservices-example.yaml
```

## Traffic Management

### Path-Based Routing

Route different paths to different services:
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: multi-service
spec:
  hosts:
  - example.com
  gateways:
  - external-gateway
  http:
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: api-service
  - match:
    - uri:
        prefix: /web
    route:
    - destination:
        host: web-service
```

### HTTP to HTTPS Redirect

Enable in Gateway:
```yaml
servers:
- port:
    number: 80
    name: http
    protocol: HTTP
  hosts:
  - "*"
  tls:
    httpsRedirect: true
```

## Monitoring Integration

Istio is integrated with the observability stack:

### Distributed Tracing
- **Backend**: Jaeger
- **Endpoint**: `jaeger-collector.greenfield:9411`
- **Sampling**: 100% (configurable in `istio-config.yaml`)

### Metrics
- **Collector**: OpenTelemetry Collector
- **Endpoint**: `otel-collector.greenfield.svc.cluster.local:4317`
- **Format**: OpenTelemetry Protocol (OTLP)

## Verification

### Check Installation
```bash
# Check Istio pods
kubectl get pods -n istio-system

# Check ingress gateways
kubectl get svc -n istio-system | grep ingressgateway

# Get LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Test HTTPS

```bash
# Get external IP
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTPS endpoint
curl -v https://myapp.example.com --resolve myapp.example.com:443:$INGRESS_HOST
```

### Check Gateway Status

```bash
# List Gateways
kubectl get gateway -n istio-system

# Describe Gateway
kubectl describe gateway external-gateway -n istio-system

# List VirtualServices
kubectl get virtualservice -A
```

## Troubleshooting

### Gateway Not Working

Check ingress gateway logs:
```bash
kubectl logs -n istio-system -l istio=ingressgateway
```

### Certificate Issues

Verify certificate:
```bash
# Check certificate status
kubectl get certificate -n istio-system

# Describe certificate
kubectl describe certificate myapp-cert -n istio-system

# Check secret exists
kubectl get secret myapp-tls -n istio-system
```

### Routing Issues

Check VirtualService:
```bash
kubectl describe virtualservice myapp -n greenfield
```

View Istio config:
```bash
# Install istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-* && export PATH=$PWD/bin:$PATH

# Analyze configuration
istioctl analyze -n istio-system

# Get proxy configuration
istioctl proxy-config routes deploy/istio-ingressgateway -n istio-system
```

## Best Practices

### Security
- ✅ **Implemented**: Separate gateways for external and internal traffic
- ✅ **Implemented**: STRICT mTLS enabled for all services in greenfield and istio-system namespaces
- ✅ **Implemented**: Automatic sidecar injection enabled for greenfield namespace
- ✅ **Implemented**: DestinationRules configured for mTLS traffic policy
- 🔧 **Configure**: cert-manager for certificate automation
- 🔧 **Maintain**: Regularly update Istio to latest stable version

**Current mTLS Configuration:**
```yaml
# STRICT mTLS enforced via PeerAuthentication
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: greenfield
spec:
  mtls:
    mode: STRICT
```

See [kustomize/base/istio/README.md](../../kustomize/base/istio/README.md) for detailed mTLS setup.

### Performance
- Configure appropriate resource limits for gateways
- Enable horizontal pod autoscaling for high traffic
- Monitor gateway metrics in Prometheus

### Organization
- Keep Gateway resources in `istio-system` namespace
- Keep VirtualService resources with their services
- Use descriptive names for routes and gateways

## Resources

- [Official Istio Documentation](https://istio.io/latest/docs/)
- [Istio Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [Istio Traffic Management](https://istio.io/latest/docs/tasks/traffic-management/)
- [cert-manager with Istio](./cert-manager.md)

