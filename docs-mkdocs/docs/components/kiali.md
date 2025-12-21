# Kiali

Kiali is a management console for Istio service mesh. It provides visualizations of the service mesh topology, health, metrics, and tracing data, making it easier to understand the structure and behavior of your microservices.

## Overview

Kiali helps you understand the structure of your service mesh by inferring the topology, and also provides the health of your mesh. Kiali provides detailed metrics, powerful validation, Grafana access, and strong integration for distributed tracing with Jaeger.

### Key Features

- **Service Mesh Topology**: Visualize the structure and health of your service mesh
- **Traffic Flow**: See real-time traffic flow between services
- **Distributed Tracing**: Integration with Jaeger for distributed tracing
- **Metrics Visualization**: Integration with Prometheus and Grafana for detailed metrics
- **Configuration Validation**: Validate Istio configuration for common errors
- **Wizards**: Guided workflows for common Istio configurations

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Kiali Dashboard                        │
│  - Service Graph Visualization                              │
│  - Traffic Metrics & Health Status                          │
│  - Distributed Tracing Integration                          │
│  - Istio Config Validation                                  │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌──────▼───────┐  ┌───────▼────────┐
│   Prometheus   │  │    Jaeger    │  │    Grafana     │
│   (Metrics)    │  │   (Traces)   │  │  (Dashboards)  │
└───────┬────────┘  └──────┬───────┘  └───────┬────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
        ┌───────────────────▼───────────────────┐
        │         Istio Service Mesh            │
        │  - Envoy Proxies (Sidecars)          │
        │  - Istiod (Control Plane)            │
        │  - Service Traffic Management        │
        └───────────────────┬───────────────────┘
                            │
        ┌───────────────────▼───────────────────┐
        │      Application Services             │
        │  - FastAPI, Grafana, Prometheus, etc. │
        └───────────────────────────────────────┘
```

## Configuration

The Kiali deployment includes integration with:

### Istio Integration
- **Root Namespace**: `istio-system`
- **Config Map**: `istio`
- **Accessible Namespaces**: All namespaces (`**`)

### Prometheus Integration
- **URL**: `http://prometheus.greenfield.svc.cluster.local:9090`
- **Purpose**: Collects metrics from Istio and applications

### Grafana Integration
- **URL**: `http://grafana.greenfield.svc.cluster.local:3000`
- **Purpose**: Custom dashboards and advanced visualizations

### Jaeger Integration
- **URL**: `http://jaeger-query.greenfield.svc.cluster.local:16686`
- **gRPC Port**: `9095`
- **Purpose**: Distributed tracing integration

## Installation

Kiali is included in the base kustomize configuration and will be deployed automatically.

### Using Kustomize

```bash
# Deploy to development
kubectl apply -k kustomize/overlays/dev/

# Deploy to production
kubectl apply -k kustomize/overlays/prod/
```

### Using Helm

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --set kiali.enabled=true
```

## Accessing Kiali

### Port Forwarding

```bash
# Forward Kiali port
kubectl port-forward -n greenfield svc/kiali 20001:20001

# Access Kiali at http://localhost:20001/kiali
```

### Using Makefile

```bash
# Set up port forwarding for all services including Kiali
make port-forward
```

### Through Istio Ingress Gateway

To expose Kiali through the Istio ingress gateway, create a VirtualService:

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

## Using Kiali

### Service Graph

The service graph is the main visualization in Kiali. It shows:

- **Services**: Represented as nodes
- **Traffic Flow**: Represented as edges with request rates
- **Health Status**: Color-coded indicators (green=healthy, yellow=warning, red=error)
- **Protocol**: HTTP, gRPC, TCP traffic types

#### Navigation

1. **Graph Tab**: Select namespace(s) to visualize
2. **Display Options**: 
   - Show/hide labels
   - Enable/disable traffic animation
   - Filter by health status
3. **Time Range**: Select time window for metrics

### Applications View

View all applications detected in the service mesh:

```
Applications → Select namespace → View details
```

For each application, you can see:
- Workloads
- Services
- Inbound/Outbound metrics
- Health status

### Workloads View

View all workloads (Deployments, StatefulSets, etc.):

```
Workloads → Select namespace → View details
```

For each workload, you can see:
- Pods
- Services
- Inbound/Outbound metrics
- Logs
- Traces

### Services View

View all services in the mesh:

```
Services → Select namespace → View details
```

For each service, you can see:
- Workloads
- Inbound traffic
- Traces
- Istio configuration

### Istio Config

Validate and view Istio configuration:

```
Istio Config → Select namespace
```

View and validate:
- VirtualServices
- DestinationRules
- Gateways
- ServiceEntries
- PeerAuthentication policies

Kiali will highlight any configuration issues with warnings or errors.

### Distributed Tracing

Access Jaeger traces directly from Kiali:

1. Navigate to a service or workload
2. Click on the "Traces" tab
3. View traces in embedded Jaeger UI
4. Click individual traces for detailed spans

## Authentication

The default configuration uses **anonymous** authentication for simplicity. For production deployments, you should configure proper authentication.

### Supported Authentication Strategies

- **anonymous**: No authentication (default in this setup)
- **token**: Kubernetes token authentication
- **openid**: OpenID Connect authentication
- **openshift**: OpenShift OAuth authentication

To change authentication strategy, update the ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kiali
  namespace: greenfield
data:
  config.yaml: |
    auth:
      strategy: token  # Change from anonymous to token
```

## Monitoring Integration

### Prometheus Metrics

Kiali itself exposes Prometheus metrics on port 9090:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
```

### Service Mesh Metrics

Kiali displays metrics from Prometheus including:

- **Request rate**: Requests per second
- **Error rate**: Percentage of failed requests
- **Duration**: Request duration percentiles (p50, p95, p99)
- **TCP metrics**: Bytes sent/received

## Best Practices

### Security

1. **Enable Authentication**: Don't use anonymous auth in production
2. **RBAC**: Use Kubernetes RBAC to control access
3. **Network Policies**: Restrict network access to Kiali
4. **TLS**: Use HTTPS when exposing Kiali externally

### Performance

1. **Namespace Selection**: Limit the number of namespaces displayed in graph view
2. **Time Range**: Use appropriate time ranges for metrics
3. **Graph Complexity**: Filter services to reduce graph complexity
4. **Resource Limits**: Adjust memory limits based on cluster size

### Usage

1. **Regular Health Checks**: Use Kiali to regularly check service mesh health
2. **Configuration Validation**: Validate Istio configs before applying
3. **Traffic Analysis**: Use traffic flow to identify bottlenecks
4. **Distributed Tracing**: Leverage Jaeger integration for debugging

## Troubleshooting

### Kiali Pod Not Starting

Check pod status:
```bash
kubectl get pods -n greenfield -l app=kiali
kubectl describe pod -n greenfield -l app=kiali
kubectl logs -n greenfield -l app=kiali
```

Common issues:
- ServiceAccount not created
- ConfigMap not found
- Insufficient RBAC permissions

### Cannot Access Service Mesh Data

Verify Istio integration:
```bash
# Check if Istio is installed
kubectl get pods -n istio-system

# Verify namespace has Istio injection enabled
kubectl get namespace greenfield -o yaml | grep istio-injection

# Check if pods have Istio sidecars
kubectl get pods -n greenfield -o jsonpath='{.items[*].spec.containers[*].name}'
```

### No Metrics Displayed

Verify Prometheus integration:
```bash
# Check Prometheus is accessible
kubectl port-forward -n greenfield svc/prometheus 9090:9090

# Visit http://localhost:9090 and verify Istio metrics are being scraped
# Look for metrics like: istio_requests_total
```

### Tracing Not Working

Verify Jaeger integration:
```bash
# Check Jaeger is running
kubectl get pods -n greenfield -l app=jaeger

# Verify Jaeger service
kubectl get svc -n greenfield jaeger-query

# Check Istio tracing configuration
kubectl get configmap istio -n istio-system -o yaml | grep -A 10 tracing
```

## Configuration Reference

### ConfigMap Settings

Key configuration options in `kiali` ConfigMap:

```yaml
auth:
  strategy: anonymous  # Authentication strategy

deployment:
  accessible_namespaces:  # Namespaces Kiali can access
  - '**'  # All namespaces

external_services:
  prometheus:
    url: http://prometheus.greenfield.svc.cluster.local:9090
  
  grafana:
    enabled: true
    url: http://grafana.greenfield.svc.cluster.local:3000
  
  tracing:
    enabled: true
    url: http://jaeger-query.greenfield.svc.cluster.local:16686
    use_grpc: true

server:
  port: 20001
  web_root: /kiali
```

### Resource Requirements

Default resource allocation:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 1Gi
```

Adjust based on:
- Cluster size
- Number of services
- Graph complexity
- Metric retention

## Resources

- [Official Kiali Documentation](https://kiali.io/docs/)
- [Kiali GitHub Repository](https://github.com/kiali/kiali)
- [Kiali Architecture](https://kiali.io/docs/architecture/)
- [Istio Integration Guide](./istio.md)
- [Prometheus Integration](./prometheus.md)
- [Jaeger Integration](./jaeger.md)
- [Grafana Integration](./grafana.md)

## Quick Reference

### Common Commands

```bash
# View Kiali logs
kubectl logs -n greenfield -l app=kiali

# Restart Kiali
kubectl rollout restart deployment/kiali -n greenfield

# Check Kiali configuration
kubectl get configmap kiali -n greenfield -o yaml

# Access Kiali UI
kubectl port-forward -n greenfield svc/kiali 20001:20001
# Then visit: http://localhost:20001/kiali
```

### Kiali Graph Display Options

- **Layout**: Choose from different graph layout algorithms
- **Display**: Toggle edge labels, service nodes, traffic animation
- **Show**: Filter by healthy, degraded, or failure status
- **Traffic**: View requests/second, response time, TCP traffic

### Helpful Links in Kiali UI

- **Overview**: Dashboard with service mesh summary
- **Graph**: Visual topology of service mesh
- **Applications**: List of applications in the mesh
- **Workloads**: List of workloads (deployments, statefulsets)
- **Services**: List of services
- **Istio Config**: Istio configuration objects
