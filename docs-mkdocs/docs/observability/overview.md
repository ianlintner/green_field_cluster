# Observability Overview

The Greenfield Cluster includes a comprehensive observability stack designed for production readiness with SLO-based monitoring and intelligent alerting.

## Components

### Metrics Collection
- **Prometheus**: Collects metrics from all cluster components and applications
- **SLO Recording Rules**: Pre-calculated metrics for Service Level Objectives
- **Service Discovery**: Automatically discovers and scrapes Kubernetes resources

### Distributed Tracing
- **OpenTelemetry Collector**: Collects traces from instrumented applications
- **Jaeger**: Stores and visualizes distributed traces
- **Integration**: Seamless integration with application code

### Visualization
- **Grafana**: Rich dashboards for metrics visualization
- **Pre-built Dashboards**: 
  - Cluster Health SLOs
  - Application Performance SLOs
  - Component-specific dashboards
- **Data Sources**: Pre-configured Prometheus and Jaeger connections

### Service Mesh Observability
- **Kiali**: Visualizes Istio service mesh topology
- **Traffic Flow**: See request flows between services
- **Metrics**: Service-level metrics from Istio

## Service Level Objectives (SLOs)

The cluster implements SLOs following Google SRE best practices:

### Cluster-Level SLOs
- **API Server Availability**: 99.9% target
- **Node Health**: 99% nodes ready
- **Pod Scheduling**: 99% success rate
- **Resource Utilization**: CPU, memory, disk thresholds

### Application-Level SLOs
- **Availability**: 99.9% request success rate
- **Latency**: P95 < 1s, P99 < 2s
- **Error Budget**: Track remaining reliability budget
- **Saturation**: Resource usage per pod

[Read more about SLOs →](slos.md)

## Alerting

Environment-aware alerting based on SLO violations:

### Alert Types
- **Critical**: Immediate action required (SLO violations, outages)
- **Warning**: Investigation needed (approaching thresholds)
- **Info**: Informational (low traffic detection)

### Environment Awareness
- **Production**: Strict thresholds, immediate notifications
- **Staging**: Moderate thresholds, delayed notifications
- **Development**: Relaxed thresholds, minimal alerting

### Low-Traffic Handling
Automatically suppress false positives in low-traffic environments (< 0.01 req/s)

[Read more about Alerts →](alerts.md)

## Optional AlertManager

AlertManager provides intelligent alert routing and grouping:

- **Multiple Receivers**: Slack, PagerDuty, email, webhook
- **Alert Grouping**: Reduces noise by grouping related alerts
- **Inhibition Rules**: Prevents alert storms
- **Silencing**: Temporary alert suppression for maintenance

By default, AlertManager is **commented out** to keep the setup minimal. Enable it when you need advanced alert routing.

## Getting Started

### 1. Access Observability Tools

```bash
# Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000
# Visit: http://localhost:3000 (admin/admin123)

# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Visit: http://localhost:9090

# Jaeger
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686
# Visit: http://localhost:16686

# Kiali
kubectl port-forward -n greenfield svc/kiali 20001:20001
# Visit: http://localhost:20001/kiali
```

### 2. View SLO Dashboards

1. Open Grafana (http://localhost:3000)
2. Navigate to Dashboards
3. Open "Cluster Health SLOs" or "Application SLOs"
4. Monitor your SLO compliance and error budgets

### 3. Check Prometheus Alerts

1. Open Prometheus (http://localhost:9090)
2. Navigate to "Alerts" tab
3. See active alerts and their status
4. Review alert rules and thresholds

### 4. Query Metrics

```bash
# Port-forward Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090

# Example queries:
# - API server availability: apiserver:availability:ratio_rate5m
# - Error budget remaining: http:requests:error_budget_remaining
# - P95 latency: http:request:duration:p95_rate5m
```

### 5. Enable AlertManager (Optional)

```bash
# 1. Edit observability kustomization
nano kustomize/base/observability/kustomization.yaml
# Uncomment: - alertmanager

# 2. Configure notification channels
nano kustomize/base/observability/alertmanager/configmap.yaml
# Add your Slack/PagerDuty/email configuration

# 3. Apply
kubectl apply -k kustomize/base/

# 4. Access AlertManager
kubectl port-forward -n greenfield svc/alertmanager 9093:9093
# Visit: http://localhost:9093
```

## Instrumenting Your Application

To get full observability for your applications:

### 1. Expose Prometheus Metrics

Add Prometheus client library to your application:

```python
# Python example with prometheus_client
from prometheus_client import Counter, Histogram, start_http_server

# Define metrics
request_count = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('http_request_duration_seconds', 'HTTP request duration')

# Instrument your code
@request_duration.time()
def handle_request():
    # Your code
    request_count.labels(method='GET', endpoint='/api', status='200').inc()
```

### 2. Add Prometheus Annotations

Add annotations to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
```

### 3. Integrate OpenTelemetry

For distributed tracing:

```python
# Python example with OpenTelemetry
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure OTLP exporter
trace.set_tracer_provider(TracerProvider())
otlp_exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True)
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(otlp_exporter))

# Use tracer
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("my-operation"):
    # Your code
    pass
```

### 4. Follow Naming Conventions

Use consistent metric names:

- **Counters**: `{component}_{what}_total` (e.g., `http_requests_total`)
- **Gauges**: `{component}_{what}` (e.g., `memory_usage_bytes`)
- **Histograms**: `{component}_{what}_duration` (e.g., `http_request_duration_seconds`)

## Best Practices

### 1. Define Your SLOs First
- Start with user-facing metrics (availability, latency)
- Set achievable targets (99% or 99.9%)
- Calculate error budgets

### 2. Alert on SLO Violations
- Don't alert on everything
- Focus on what impacts users
- Use error budgets to balance reliability and velocity

### 3. Use Dashboards for Investigation
- Alerts tell you something is wrong
- Dashboards help you understand why
- Keep dashboards simple and actionable

### 4. Instrument Everything
- Add metrics to all applications
- Include distributed tracing
- Log structured data

### 5. Review Regularly
- Monthly SLO review meetings
- Adjust thresholds based on data
- Update runbooks with learnings

## Troubleshooting

### Metrics Not Appearing

**Check Prometheus targets**:
```bash
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

Ensure your service has:
- Prometheus annotations
- Metrics endpoint responding
- Correct port number

### Alerts Not Firing

**Check Prometheus rules**:
```bash
# Check Prometheus logs
kubectl logs -n greenfield deployment/prometheus | grep -i error

# Test alert expression manually
# Visit: http://localhost:9090/graph
# Enter alert expression
```

### Traces Not Visible

**Check OpenTelemetry Collector**:
```bash
kubectl logs -n greenfield deployment/otel-collector

# Verify endpoint in your app:
# http://otel-collector:4317
```

### High Cardinality Metrics

Avoid labels with many unique values:
- ❌ User IDs, request IDs
- ❌ Full URLs
- ✅ Method, status code, endpoint pattern

## Further Reading

- [Service Level Objectives (SLOs)](slos.md) - Detailed SLO implementation guide
- [Alerting](alerts.md) - Alert rules and AlertManager configuration
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Google SRE Book](https://sre.google/books/) - SLO best practices
