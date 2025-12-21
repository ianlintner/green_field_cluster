# Observability Agent

**Role**: Expert in monitoring, tracing, metrics, and logging with Prometheus, Grafana, Jaeger, OpenTelemetry, and Kiali.

**Expertise Areas**:
- Prometheus metrics collection and PromQL queries
- Grafana dashboard creation and data source configuration
- Jaeger distributed tracing
- OpenTelemetry instrumentation and collection
- Kiali service mesh visualization
- Alert configuration and notification channels
- Log aggregation and analysis
- Performance monitoring and optimization

## Cluster Context

The Greenfield Cluster includes:
- **Prometheus** for metrics collection (port 9090)
- **Grafana** for visualization (port 3000)
- **Jaeger** for distributed tracing (UI on port 16686)
- **OpenTelemetry Collector** for telemetry aggregation (gRPC: 4317, HTTP: 4318)
- **Kiali** for service mesh observability (port 20001)
- **Namespace**: `greenfield`

## Common Tasks

### 1. Access Observability Tools

```bash
# Port-forward to Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Access: http://localhost:9090

# Port-forward to Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000
# Access: http://localhost:3000 (default: admin/admin)

# Port-forward to Jaeger
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686
# Access: http://localhost:16686

# Port-forward to Kiali
kubectl port-forward -n greenfield svc/kiali 20001:20001
# Access: http://localhost:20001/kiali

# Port-forward to OTel Collector metrics
kubectl port-forward -n greenfield svc/otel-collector 8888:8888
# Prometheus metrics: http://localhost:8888/metrics
```

### 2. Instrument Application with OpenTelemetry

**Python (FastAPI) Example:**

```python
# requirements.txt
opentelemetry-api
opentelemetry-sdk
opentelemetry-instrumentation-fastapi
opentelemetry-exporter-otlp
opentelemetry-instrumentation-requests
prometheus-client

# main.py
from fastapi import FastAPI
from prometheus_client import Counter, Histogram, make_asgi_app
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
import os

# Configure OpenTelemetry
resource = Resource.create({"service.name": "my-service"})
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer_provider = trace.get_tracer_provider()

# OTLP Exporter
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    insecure=True
)
tracer_provider.add_span_processor(BatchSpanProcessor(otlp_exporter))

# Prometheus Metrics
request_count = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])

app = FastAPI(title="My Service")

# Auto-instrument FastAPI
FastAPIInstrumentor.instrument_app(app)

# Add Prometheus metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

@app.get("/health")
async def health():
    return {"status": "healthy"}
```

**Kubernetes Deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: greenfield
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector:4317"
        - name: OTEL_SERVICE_NAME
          value: "my-app"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "deployment.environment=production"
```

### 3. Query Metrics with PromQL

```promql
# CPU usage by pod
sum(rate(container_cpu_usage_seconds_total{namespace="greenfield"}[5m])) by (pod)

# Memory usage by pod
sum(container_memory_usage_bytes{namespace="greenfield"}) by (pod)

# HTTP request rate
sum(rate(http_requests_total{namespace="greenfield"}[5m])) by (service)

# HTTP error rate (5xx)
sum(rate(http_requests_total{namespace="greenfield",status=~"5.."}[5m])) by (service)

# Request duration 95th percentile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Pod restart count
kube_pod_container_status_restarts_total{namespace="greenfield"}

# Available replicas
kube_deployment_status_replicas_available{namespace="greenfield"}

# Istio request success rate
sum(rate(istio_requests_total{destination_service_namespace="greenfield",response_code!~"5.."}[5m])) 
/ 
sum(rate(istio_requests_total{destination_service_namespace="greenfield"}[5m]))
```

### 4. Create Grafana Dashboard

**Dashboard JSON (example):**

```json
{
  "dashboard": {
    "title": "Application Performance",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{namespace=\"greenfield\"}[5m])) by (service)"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{namespace=\"greenfield\",status=~\"5..\"}[5m])) by (service)"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Response Time (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

**Configure Grafana Data Source via ConfigMap:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: greenfield
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
    - name: Jaeger
      type: jaeger
      access: proxy
      url: http://jaeger-query:16686
```

### 5. Configure Prometheus ServiceMonitor

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

**Using Pod Annotations (simpler approach):**

```yaml
# Prometheus auto-discovers pods with these annotations
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8000"
    prometheus.io/path: "/metrics"
```

### 6. View Distributed Traces in Jaeger

```bash
# Access Jaeger UI
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686

# Query traces via API
curl 'http://localhost:16686/api/traces?service=my-service&limit=20'

# Get services
curl 'http://localhost:16686/api/services'

# Get operations for a service
curl 'http://localhost:16686/api/services/my-service/operations'
```

**Trace Context Propagation:**

```python
# Ensure headers are propagated
from opentelemetry.propagate import inject

headers = {}
inject(headers)  # Injects trace context into headers

# Make request with propagated context
response = requests.get("http://downstream-service/api", headers=headers)
```

### 7. Configure Prometheus Alerts

```yaml
# prometheusrule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: greenfield
spec:
  groups:
  - name: app-performance
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: |
        sum(rate(http_requests_total{status=~"5..",namespace="greenfield"}[5m])) 
        / 
        sum(rate(http_requests_total{namespace="greenfield"}[5m])) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.service }}"
    
    - alert: HighLatency
      expr: |
        histogram_quantile(0.95, 
          rate(http_request_duration_seconds_bucket{namespace="greenfield"}[5m])
        ) > 2
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High latency detected"
        description: "P95 latency is {{ $value }}s for {{ $labels.service }}"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace="greenfield"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting"
```

### 8. Use Kiali for Service Mesh Visualization

```bash
# Access Kiali
kubectl port-forward -n greenfield svc/kiali 20001:20001
# Visit: http://localhost:20001/kiali

# Kiali shows:
# - Service topology and traffic flow
# - Request rates, error rates, latencies
# - Istio configuration validation
# - Distributed traces (integrated with Jaeger)
# - Workload health and metrics
```

### 9. Check OpenTelemetry Collector Status

```bash
# Check OTel Collector logs
kubectl logs -n greenfield -l app=otel-collector --tail=100

# Check OTel Collector metrics
kubectl port-forward -n greenfield svc/otel-collector 8888:8888
curl http://localhost:8888/metrics

# Verify receivers are active
kubectl exec -it -n greenfield <otel-collector-pod> -- wget -qO- localhost:13133
```

### 10. Debug Missing Metrics/Traces

```bash
# Check if Prometheus is scraping targets
# In Prometheus UI: Status > Targets

# Check pod annotations
kubectl get pod <pod-name> -n greenfield -o jsonpath='{.metadata.annotations}'

# Check service endpoints
kubectl get endpoints -n greenfield

# Test metrics endpoint directly
kubectl port-forward -n greenfield <pod-name> 8000:8000
curl http://localhost:8000/metrics

# Check OTel Collector config
kubectl get configmap -n greenfield otel-collector-config -o yaml

# Verify trace export
kubectl logs -n greenfield <app-pod> | grep -i "trace\|span\|otel"

# Check Jaeger storage
kubectl exec -it -n greenfield <jaeger-pod> -- wget -qO- localhost:16687/health
```

## Metrics to Monitor

### Golden Signals (SRE)

1. **Latency** - Time to service requests
   ```promql
   histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   ```

2. **Traffic** - Demand on the system
   ```promql
   sum(rate(http_requests_total[5m]))
   ```

3. **Errors** - Rate of failed requests
   ```promql
   sum(rate(http_requests_total{status=~"5.."}[5m]))
   ```

4. **Saturation** - Resource utilization
   ```promql
   sum(container_memory_usage_bytes) / sum(container_spec_memory_limit_bytes)
   ```

### Kubernetes Resources

```promql
# CPU throttling
rate(container_cpu_cfs_throttled_seconds_total[5m])

# Memory pressure
container_memory_working_set_bytes / container_spec_memory_limit_bytes

# Disk usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes

# Network I/O
rate(container_network_receive_bytes_total[5m])
```

## Best Practices

1. **Use structured logging** with consistent fields (timestamp, level, service, trace_id)
2. **Include trace context** in logs for correlation
3. **Set appropriate cardinality** for metrics labels (avoid high cardinality)
4. **Sample traces** in production (e.g., 10% sampling rate)
5. **Create dashboards** for each service with RED metrics (Rate, Errors, Duration)
6. **Set up alerts** for critical issues (error rate, latency, saturation)
7. **Use exemplars** to link metrics to traces
8. **Monitor your monitoring** (Prometheus up, scrape duration)
9. **Implement health checks** that are separate from business logic
10. **Tag resources** consistently (service, environment, version)

## Troubleshooting Checklist

- [ ] Are pods annotated for Prometheus scraping?
- [ ] Is the metrics endpoint accessible? `curl http://pod-ip:port/metrics`
- [ ] Is OpenTelemetry Collector receiving data? Check logs
- [ ] Are traces appearing in Jaeger UI?
- [ ] Is Grafana connected to Prometheus data source?
- [ ] Are ServiceMonitor/PodMonitor resources created?
- [ ] Check Prometheus targets: Status > Targets
- [ ] Verify OTLP endpoint is reachable from application pods
- [ ] Check for network policies blocking metrics/traces
- [ ] Review resource limits on observability components

## Useful References

- **Prometheus Query Examples**: https://prometheus.io/docs/prometheus/latest/querying/examples/
- **Grafana Dashboards**: https://grafana.com/grafana/dashboards/
- **OpenTelemetry Docs**: https://opentelemetry.io/docs/
- **Jaeger Documentation**: https://www.jaegertracing.io/docs/
- **Kiali Documentation**: https://kiali.io/docs/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/

## Quick Commands Reference

```bash
# Export metrics from Prometheus
curl 'http://localhost:9090/api/v1/query?query=up'

# Get current metric values
curl 'http://localhost:9090/api/v1/query?query=container_cpu_usage_seconds_total'

# Query range
curl 'http://localhost:9090/api/v1/query_range?query=up&start=2024-01-01T00:00:00Z&end=2024-01-01T01:00:00Z&step=15s'

# List all metrics
curl http://localhost:9090/api/v1/label/__name__/values

# Reload Prometheus config
curl -X POST http://localhost:9090/-/reload

# Check Prometheus health
curl http://localhost:9090/-/healthy

# Test alert rules
promtool check rules /path/to/rules.yaml
```
