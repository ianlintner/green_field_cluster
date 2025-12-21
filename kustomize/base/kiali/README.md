# Kiali

This directory contains Kustomize manifests for deploying Kiali, a management console for Istio service mesh.

## Overview

Kiali provides observability for your Istio service mesh, including:

- Service mesh topology visualization
- Traffic flow and health status
- Integration with Prometheus, Grafana, and Jaeger
- Istio configuration validation
- Distributed tracing integration

## Resources

This directory includes:

- **configmap.yaml**: Kiali configuration with integration settings
- **deployment.yaml**: Kiali deployment specification
- **service.yaml**: Kiali service for UI access
- **rbac.yaml**: ServiceAccount, ClusterRole, and ClusterRoleBinding for Kiali
- **kustomization.yaml**: Kustomize configuration with secret generation

## Prerequisites

Before deploying Kiali, ensure the following are installed and configured:

1. **Istio**: Service mesh installed in `istio-system` namespace
2. **Prometheus**: Metrics collection service running
3. **Grafana** (optional): Dashboard service for enhanced visualization
4. **Jaeger** (optional): Distributed tracing service

## Configuration

### Integrated Services

Kiali is configured to integrate with:

- **Istio**: Root namespace `istio-system`
- **Prometheus**: `http://prometheus.greenfield.svc.cluster.local:9090`
- **Grafana**: `http://grafana.greenfield.svc.cluster.local:3000`
- **Jaeger**: `http://jaeger-query.greenfield.svc.cluster.local:16686`

### Authentication

Default authentication strategy is `anonymous` for ease of use in development. For production, consider changing to:

- `token`: Kubernetes token authentication
- `openid`: OpenID Connect authentication

Update the ConfigMap to change authentication:

```yaml
auth:
  strategy: token
```

### Accessible Namespaces

Kiali is configured to access all namespaces (`**`). To limit access, update the ConfigMap:

```yaml
deployment:
  accessible_namespaces:
  - greenfield
  - istio-system
```

## Deployment

### Standalone Deployment

Deploy Kiali independently:

```bash
kubectl apply -k kustomize/base/kiali/
```

### With Base Configuration

Kiali is included in the base kustomization and will be deployed automatically:

```bash
kubectl apply -k kustomize/base/
```

### Verify Deployment

Check if Kiali is running:

```bash
# Check pods
kubectl get pods -n greenfield -l app=kiali

# Check service
kubectl get svc -n greenfield kiali

# Check logs
kubectl logs -n greenfield -l app=kiali
```

## Accessing Kiali

### Port Forwarding

Forward the Kiali port to your local machine:

```bash
kubectl port-forward -n greenfield svc/kiali 20001:20001
```

Then access Kiali at: http://localhost:20001/kiali

### Via Istio Ingress Gateway

Create a VirtualService to expose Kiali through Istio ingress:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: kiali
  namespace: greenfield
spec:
  hosts:
  - kiali.example.com
  gateways:
  - istio-system/external-gateway
  http:
  - match:
    - uri:
        prefix: /kiali
    route:
    - destination:
        host: kiali.greenfield.svc.cluster.local
        port:
          number: 20001
```

## Customization

### Resource Limits

Adjust resource limits based on your cluster size:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

### Image Version

To use a different Kiali version, update the deployment:

```yaml
image: quay.io/kiali/kiali:v1.79.0  # Change version as needed
```

### Configuration Options

Modify the ConfigMap to customize Kiali behavior:

- **Log Level**: `LOG_LEVEL` environment variable (info, debug, trace)
- **Log Format**: `LOG_FORMAT` environment variable (text, json)
- **Web Root**: Change the URL path prefix
- **Metrics Port**: Expose Prometheus metrics on a different port

## Integration with Observability Stack

Kiali works best when integrated with the full observability stack:

```
┌─────────────────┐
│     Kiali       │  ← User Interface
└────────┬────────┘
         │
    ┌────┴─────┐
    │          │
┌───▼───┐  ┌──▼──────┐  ┌──────────┐
│Istio  │  │Prometheus│  │  Jaeger  │
│(Mesh) │  │(Metrics) │  │ (Traces) │
└───────┘  └──────────┘  └──────────┘
```

## Troubleshooting

### Kiali Not Starting

1. Check if ServiceAccount exists:
   ```bash
   kubectl get sa kiali -n greenfield
   ```

2. Verify RBAC permissions:
   ```bash
   kubectl get clusterrole kiali
   kubectl get clusterrolebinding kiali
   ```

3. Check ConfigMap:
   ```bash
   kubectl get configmap kiali -n greenfield
   ```

### Cannot See Service Mesh

1. Verify Istio is installed:
   ```bash
   kubectl get pods -n istio-system
   ```

2. Check if namespace has Istio injection enabled:
   ```bash
   kubectl get namespace greenfield -o yaml | grep istio-injection
   ```

3. Verify services have Istio sidecars:
   ```bash
   kubectl get pods -n greenfield -o jsonpath='{.items[*].spec.containers[*].name}'
   ```

### No Metrics Displayed

1. Verify Prometheus URL in ConfigMap
2. Check if Prometheus is accessible from Kiali pod:
   ```bash
   kubectl exec -n greenfield deployment/kiali -- curl -s http://prometheus.greenfield.svc.cluster.local:9090/api/v1/targets
   ```

## Security Considerations

1. **Authentication**: Enable proper authentication in production
2. **RBAC**: Review and restrict ClusterRole permissions as needed
3. **Network Policies**: Implement network policies to restrict access
4. **TLS**: Use HTTPS when exposing Kiali externally
5. **Secrets**: Store sensitive data in Kubernetes secrets

## Resources

- [Kiali Documentation](https://kiali.io/docs/)
- [Component Documentation](../../../../docs-mkdocs/docs/components/kiali.md)
- [Istio Integration Guide](../istio/README.md)
- [Kiali GitHub](https://github.com/kiali/kiali)

## Version

Current Kiali version: **v1.79.0**

For updates, check: https://kiali.io/news/releases/
