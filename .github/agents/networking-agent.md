# Networking & Service Mesh Agent

**Role**: Expert in Istio service mesh, ingress/egress configuration, traffic management, SSL/TLS, and network policies.

**Expertise Areas**:
- Istio service mesh configuration and troubleshooting
- Gateway setup (ingress and egress)
- Virtual Services and Destination Rules
- Traffic management (routing, splitting, mirroring)
- SSL/TLS certificate management with cert-manager
- mTLS configuration and policies
- Circuit breakers, retries, and timeouts
- Network policies and security

## Cluster Context

The Greenfield Cluster uses:
- **Istio** for service mesh with sidecar injection
- **cert-manager** for SSL/TLS certificate automation
- **Namespace**: `greenfield` (or environment-specific: `greenfield-dev`, `greenfield-staging`, `greenfield-prod`)
- **Istio namespace**: `istio-system`

## Common Tasks

### 1. Check Istio Installation Status

```bash
# Check Istio components
kubectl get pods -n istio-system

# Verify Istio injection is enabled
kubectl get namespace greenfield -o jsonpath='{.metadata.labels.istio-injection}'

# Check Istio version
istioctl version

# Validate Istio configuration
istioctl analyze -n greenfield
```

### 2. Enable Istio Injection for a Namespace

```bash
# Enable automatic sidecar injection
kubectl label namespace greenfield istio-injection=enabled

# Verify label
kubectl get namespace greenfield --show-labels

# Restart pods to inject sidecars
kubectl rollout restart deployment -n greenfield
```

### 3. Create an Ingress Gateway

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-app-gateway
  namespace: greenfield
spec:
  selector:
    istio: ingressgateway  # Use Istio's default ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.example.com"
    tls:
      httpsRedirect: true  # Redirect HTTP to HTTPS
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "myapp.example.com"
    tls:
      mode: SIMPLE
      credentialName: myapp-tls-cert  # Certificate from cert-manager
```

```bash
kubectl apply -f gateway.yaml
```

### 4. Create a Virtual Service for Traffic Routing

```yaml
# virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vs
  namespace: greenfield
spec:
  hosts:
  - "myapp.example.com"
  gateways:
  - my-app-gateway
  http:
  - match:
    - uri:
        prefix: "/api"
    route:
    - destination:
        host: my-app-service
        port:
          number: 8080
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
      retryOn: "5xx,reset,connect-failure,refused-stream"
```

```bash
kubectl apply -f virtualservice.yaml
```

### 5. Configure SSL/TLS with cert-manager

```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls-cert
  namespace: istio-system  # Must be in istio-system for Gateway
spec:
  secretName: myapp-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
  - www.myapp.example.com
```

```bash
kubectl apply -f certificate.yaml

# Check certificate status
kubectl get certificate -n istio-system myapp-tls-cert
kubectl describe certificate -n istio-system myapp-tls-cert

# Check if secret was created
kubectl get secret -n istio-system myapp-tls-cert
```

### 6. Traffic Splitting (Canary Deployment)

```yaml
# canary-virtualservice.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-canary
  namespace: greenfield
spec:
  hosts:
  - my-app-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: my-app-service
        subset: v2
  - route:
    - destination:
        host: my-app-service
        subset: v1
      weight: 90
    - destination:
        host: my-app-service
        subset: v2
      weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-dr
  namespace: greenfield
spec:
  host: my-app-service
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### 7. Configure Circuit Breaker

```yaml
# circuit-breaker.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-circuit-breaker
  namespace: greenfield
spec:
  host: my-app-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
```

### 8. Enable mTLS for a Namespace

```yaml
# mtls-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: greenfield
spec:
  mtls:
    mode: STRICT  # or PERMISSIVE for gradual migration
```

```bash
kubectl apply -f mtls-policy.yaml

# Verify mTLS status
istioctl authn tls-check <pod-name>.greenfield <service-name>.greenfield
```

### 9. Create Authorization Policy

```yaml
# authz-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: my-app-authz
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: my-app
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/greenfield/sa/frontend-service"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

### 10. Troubleshoot Networking Issues

```bash
# Check gateway status
kubectl get gateway -n greenfield
kubectl describe gateway my-app-gateway -n greenfield

# Check virtual services
kubectl get virtualservice -n greenfield
kubectl describe virtualservice my-app-vs -n greenfield

# Check destination rules
kubectl get destinationrule -n greenfield

# Analyze Istio configuration
istioctl analyze -n greenfield

# Check ingress gateway logs
kubectl logs -n istio-system -l app=istio-ingressgateway --tail=100

# Check if sidecar is injected
kubectl get pod <pod-name> -n greenfield -o jsonpath='{.spec.containers[*].name}'

# Describe pod to see sidecar
kubectl describe pod <pod-name> -n greenfield

# Check proxy configuration
istioctl proxy-config routes <pod-name> -n greenfield

# Check listeners
istioctl proxy-config listeners <pod-name> -n greenfield

# Check clusters
istioctl proxy-config clusters <pod-name> -n greenfield

# Debug with port-forward to envoy admin
kubectl port-forward -n greenfield <pod-name> 15000:15000
# Then visit http://localhost:15000/config_dump
```

## Traffic Management Patterns

### A/B Testing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ab-test
  namespace: greenfield
spec:
  hosts:
  - my-service
  http:
  - match:
    - headers:
        user-agent:
          regex: ".*Mobile.*"
    route:
    - destination:
        host: my-service
        subset: mobile
  - route:
    - destination:
        host: my-service
        subset: desktop
```

### Request Mirroring (Dark Launch)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mirror-traffic
  namespace: greenfield
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
        subset: v1
      weight: 100
    mirror:
      host: my-service
      subset: v2
    mirrorPercentage:
      value: 10.0  # Mirror 10% of traffic
```

### Request Timeout and Retry

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: resilience
  namespace: greenfield
spec:
  hosts:
  - my-service
  http:
  - route:
    - destination:
        host: my-service
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: "5xx,reset,connect-failure"
```

## Network Policy Example

```yaml
# network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: my-app-netpol
  namespace: greenfield
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: greenfield
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  - to:  # Allow DNS
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

## Best Practices

1. **Always use mTLS** in production for service-to-service communication
2. **Test gateway configs** with `istioctl analyze` before applying
3. **Use specific hosts** in VirtualServices, avoid wildcards
4. **Set reasonable timeouts** based on application SLAs
5. **Implement circuit breakers** for resilience
6. **Use TLS secrets in istio-system** namespace for Gateway
7. **Monitor ingress gateway logs** for SSL/TLS issues
8. **Use subsets and destination rules** for version-based routing
9. **Test canary deployments** gradually increase traffic percentage
10. **Document traffic routing** decisions in comments

## Useful References

- **Istio Documentation**: https://istio.io/latest/docs/
- **cert-manager Documentation**: https://cert-manager.io/docs/
- **Istio Traffic Management**: https://istio.io/latest/docs/concepts/traffic-management/
- **Istio Security**: https://istio.io/latest/docs/concepts/security/
- **Kiali Dashboard** (installed in cluster): Port-forward to visualize service mesh

## Quick Commands Reference

```bash
# Get Istio ingress gateway external IP
kubectl get svc istio-ingressgateway -n istio-system

# Test connectivity to a service
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://my-service.greenfield:8080

# Check Istio proxy status
istioctl proxy-status

# View effective configuration for a workload
istioctl proxy-config all <pod-name> -n greenfield

# Enable Envoy access logs
kubectl set env deployment -n istio-system istio-ingressgateway ISTIO_META_LOG_LEVEL=debug

# Inject Istio sidecar manually
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

## Troubleshooting Checklist

- [ ] Is Istio sidecar injected? Check with `kubectl get pod -o jsonpath='{.spec.containers[*].name}'`
- [ ] Is the namespace labeled for injection? `kubectl get ns <namespace> --show-labels`
- [ ] Are Gateway and VirtualService in the correct namespace?
- [ ] Does the Gateway selector match ingress gateway pods?
- [ ] Is the TLS secret in the correct namespace (istio-system)?
- [ ] Does cert-manager certificate show as Ready?
- [ ] Are DNS records pointing to the ingress gateway IP?
- [ ] Check `istioctl analyze` for configuration issues
- [ ] Review ingress gateway logs for connection errors
- [ ] Verify DestinationRule subsets match pod labels
