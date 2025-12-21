# Istio Installation Guide

This directory contains the configuration for Istio service mesh with SSL/TLS ingress support.

**📖 For complete ingress configuration with DNS setup, TLS certificates, and cloud provider guides, see the [Ingress URLs Configuration Guide](../../../docs-mkdocs/docs/networking/ingress-configuration.md).**

## Installation

Istio should be installed separately using the Istio operator or Helm chart before applying the application manifests.

### Using Istio Operator:

```bash
# Install Istio operator
kubectl apply -f https://github.com/istio/istio/releases/download/1.20.0/istio-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=600s deployment/istio-operator -n istio-operator

# Install Istio control plane with ingress gateways
kubectl apply -f istio-config.yaml
```

### Using Helm:

```bash
# Add Istio Helm repository
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install Istio base
helm install istio-base istio/base -n istio-system --create-namespace

# Install Istiod
helm install istiod istio/istiod -n istio-system --wait

# Install external ingress gateway
helm install istio-ingressgateway istio/gateway \
  -n istio-system \
  --set labels.istio=ingressgateway \
  --set labels.gateway-type=external

# Install internal ingress gateway
helm install istio-ingressgateway-internal istio/gateway \
  -n istio-system \
  --set labels.istio=ingressgateway-internal \
  --set labels.gateway-type=internal \
  --set service.type=ClusterIP
```

## Ingress Gateways

This configuration includes two ingress gateways:

### External Gateway (`istio-ingressgateway`)
- **Type**: LoadBalancer
- **Purpose**: Public-facing services with SSL/TLS termination
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Selector**: `istio: ingressgateway`, `gateway-type: external`

### Internal Gateway (`istio-ingressgateway-internal`)
- **Type**: ClusterIP
- **Purpose**: Internal services within the cluster
- **Ports**: 80 (HTTP), 443 (HTTPS with mTLS)
- **Selector**: `istio: ingressgateway-internal`, `gateway-type: internal`

## Gateway Resources

After Istio is installed, apply the Gateway configurations:

```bash
kubectl apply -f gateways.yaml
```

This creates:
- `external-gateway`: For public HTTPS traffic with TLS termination
- `internal-gateway`: For internal services with mTLS

## SSL/TLS Certificates

To use SSL/TLS with the gateways:

1. **Install cert-manager** (see [cert-manager documentation](../cert-manager/README.md))
2. **Configure DNS** (see [DNS Configuration Guides](../../../docs-mkdocs/docs/networking/dns-aws.md))
3. **Create Certificate resources** (see `certificates-example.yaml` for examples)
4. **Reference the certificate** in your Gateway configuration

For a complete walkthrough, see the [Ingress URLs Configuration Guide](../../../docs-mkdocs/docs/networking/ingress-configuration.md).

Example certificate in istio-system namespace:

```bash
kubectl apply -f certificates-example.yaml
```

This will create TLS secrets that can be referenced in Gateway configurations.

## VirtualService Examples

See `virtualservices-example.yaml` for example routing configurations:

- External API access via `api.example.com`
- Internal monitoring dashboard access
- Path-based routing

For more advanced examples including canary routing, CORS, and complete setups, see `ingress-complete-example.yaml`.

To use the examples:

```bash
# Update the example files with your actual domain names
kubectl apply -f virtualservices-example.yaml

# Or use the complete example with certificates and routing
kubectl apply -f ingress-complete-example.yaml
```

## Mutual TLS (mTLS) Configuration

This configuration includes PeerAuthentication policies to enforce STRICT mutual TLS between all services in the mesh:

### PeerAuthentication Policies

Two PeerAuthentication policies are configured:

1. **Greenfield Namespace Policy** (`peer-authentication.yaml`)
   - Enforces STRICT mTLS for all services in the `greenfield` namespace
   - All service-to-service communication within the namespace requires mutual TLS

2. **Istio System Namespace Policy** (`peer-authentication.yaml`)
   - Enforces STRICT mTLS for all services in the `istio-system` namespace
   - Ensures control plane components also use mTLS

### DestinationRule for mTLS

DestinationRules (`destination-rule.yaml`) configure client-side traffic policies:

1. **Greenfield Namespace Rule**
   - Applies to all services (`*.greenfield.svc.cluster.local`)
   - Uses `ISTIO_MUTUAL` TLS mode for automatic mTLS certificate management

2. **Istio System Namespace Rule**
   - Applies to all services (`*.istio-system.svc.cluster.local`)
   - Uses `ISTIO_MUTUAL` TLS mode

### Sidecar Injection

The `greenfield` namespace has the `istio-injection: enabled` label, which means:
- All pods created in the namespace automatically get an Istio sidecar proxy injected
- The sidecar handles mTLS encryption/decryption transparently
- No application code changes are required

To manually control sidecar injection for specific workloads, add annotations:

```yaml
# Enable injection for specific pod
metadata:
  annotations:
    sidecar.istio.io/inject: "true"

# Disable injection for specific pod
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

## Verification

```bash
# Check Istio installation
kubectl get pods -n istio-system

# Check ingress gateways
kubectl get svc -n istio-system | grep ingressgateway

# Verify namespace injection
kubectl get namespace greenfield -o yaml | grep istio-injection

# Check Gateway resources
kubectl get gateway -n istio-system

# Check VirtualService resources
kubectl get virtualservice -A

# Verify PeerAuthentication policies
kubectl get peerauthentication -A

# Check DestinationRules
kubectl get destinationrule -A

# Verify mTLS is enabled for a service
istioctl authn tls-check <pod-name>.<namespace> <service-name>.<namespace>.svc.cluster.local
```

## Testing SSL/TLS

After setting up certificates:

```bash
# Get the external LoadBalancer IP
export INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTPS endpoint (replace with your domain)
curl -v https://api.example.com --resolve api.example.com:443:$INGRESS_HOST
```

## Troubleshooting

Check Istio ingress gateway logs:

```bash
# External gateway
kubectl logs -n istio-system -l istio=ingressgateway

# Internal gateway
kubectl logs -n istio-system -l istio=ingressgateway-internal
```

Check Gateway status:

```bash
kubectl describe gateway external-gateway -n istio-system
kubectl describe gateway internal-gateway -n istio-system
```

## Important Notes

- **cert-manager Required**: SSL/TLS functionality requires cert-manager to be installed
- **DNS Configuration**: Ensure your domain's DNS points to the LoadBalancer IP
- **Certificate Secrets**: Must be in the `istio-system` namespace
- **HTTP to HTTPS Redirect**: Uncomment the `httpsRedirect` option in gateways.yaml to enable
- **mTLS Enforcement**: PeerAuthentication policies enforce STRICT mTLS for all services in greenfield and istio-system namespaces
- **Automatic Sidecar Injection**: All pods in the greenfield namespace automatically receive Istio sidecars due to the namespace label
- **Zero Application Changes**: Applications don't need code changes for mTLS - the Istio sidecar handles encryption transparently

