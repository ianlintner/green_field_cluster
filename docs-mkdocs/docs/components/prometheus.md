# Prometheus

Prometheus is the metrics collection and storage system for the Greenfield Cluster, providing the foundation for monitoring, alerting, and SLO tracking.

## Overview

Prometheus collects time-series metrics from:
- Kubernetes cluster components (API server, nodes, pods)
- Infrastructure services (Redis, PostgreSQL, MongoDB, etc.)
- Applications with Prometheus client libraries
- Service mesh metrics via Istio

## Features

### Metrics Collection
- **Automatic Service Discovery**: Discovers Kubernetes services and pods
- **Scraping**: Pulls metrics from targets every 15 seconds
- **Recording Rules**: Pre-calculated SLO metrics for performance
- **Alert Rules**: SLO-based alerts for cluster and application health

### Storage
- **Time Series Database**: Efficient storage for metrics over time
- **Retention**: Default 15 days (configurable)
- **Local Storage**: Uses EmptyDir by default (consider PVC for production)

### Querying
- **PromQL**: Powerful query language for metrics
- **Grafana Integration**: Datasource for visualization
- **Alert Evaluation**: Continuously evaluates alert rules

## Configuration

### Default Configuration

Located at `kustomize/base/prometheus/configmap.yaml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'greenfield-cluster'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - '/etc/prometheus/rules/*.yml'
```

### Scrape Configs

Pre-configured to scrape:
- **Prometheus itself**: `localhost:9090`
- **OpenTelemetry Collector**: `otel-collector:8889`
- **FastAPI App**: `fastapi-app:8000`
- **Kubernetes API Server**: Via service discovery
- **Kubernetes Pods**: With `prometheus.io/scrape: "true"` annotation

### SLO Recording Rules

The cluster includes comprehensive SLO recording rules:

#### Cluster SLOs
- `apiserver:availability:ratio_rate5m` - API server availability
- `node:health:ratio` - Node health percentage
- `pod:scheduling:success_ratio_rate5m` - Pod scheduling success
- `cluster:cpu:utilization` - Cluster CPU usage
- `cluster:memory:utilization` - Cluster memory usage

#### Application SLOs
- `http:requests:success_ratio_rate5m` - Request success rate
- `http:requests:error_budget_remaining` - Error budget
- `http:request:duration:p95_rate5m` - P95 latency
- `pod:cpu:saturation` - Pod CPU saturation
- `pod:memory:saturation` - Pod memory saturation

See the [SLOs documentation](../observability/slos.md) for complete details.

### Alert Rules

Alert rules are defined for:
- Cluster health (API server, nodes, scheduling)
- Resource utilization (CPU, memory, disk)
- Application SLO violations (errors, latency, saturation)
- Environment-aware thresholds

See the [Alerts documentation](../observability/alerts.md) for complete details.

## Accessing Prometheus

### Port Forward

```bash
kubectl port-forward -n greenfield svc/prometheus 9090:9090
```

Then visit: http://localhost:9090

### UI Features

#### Metrics Explorer
- **Graph**: Visualize metrics over time
- **Table**: View current values
- **Autocomplete**: Discover available metrics

#### Alert Management
- **Alerts Tab**: View active alerts and their status
- **Alert Rules**: See all configured alert rules
- **Alertmanager**: View connected AlertManager instances

#### Configuration
- **Status → Targets**: See all scrape targets and their health
- **Status → Rules**: View recording and alerting rules
- **Status → Configuration**: View current Prometheus config

## Querying Metrics

### Example Queries

#### Basic Queries
```promql
# Current API server availability
apiserver:availability:ratio_rate5m

# Error budget remaining
http:requests:error_budget_remaining

# P95 latency by app
http:request:duration:p95_rate5m

# Pod CPU usage
pod:cpu:saturation
```

#### Advanced Queries
```promql
# Request rate per app
sum(rate(http_requests_total[5m])) by (app, namespace)

# Error rate by status code
sum(rate(http_requests_total{status=~"5.."}[5m])) by (status)

# Memory usage per pod
sum(container_memory_working_set_bytes{container!=""}) by (pod, namespace)

# Top 5 pods by CPU
topk(5, pod:cpu:saturation)
```

#### PromQL Tips
- Use `rate()` for counters
- Use `increase()` for total change
- Use `histogram_quantile()` for percentiles
- Use `by (label)` to aggregate
- Use `{label="value"}` to filter

## Instrumenting Applications

### Add Prometheus Scraping

Annotate your deployment:

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

### Expose Metrics Endpoint

Use a Prometheus client library:

**Python**:
```python
from prometheus_client import Counter, Histogram, start_http_server

requests_total = Counter('http_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
request_duration = Histogram('http_request_duration_seconds', 'Request duration')

# In your handler
requests_total.labels(method='GET', endpoint='/api', status='200').inc()

# Start metrics server
start_http_server(8000)
```

**Go**:
```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal)
}

// In your handler
requestsTotal.WithLabelValues("GET", "/api", "200").Inc()

// Expose metrics
http.Handle("/metrics", promhttp.Handler())
```

### Metric Naming Conventions

Follow Prometheus best practices:
- **Counters**: `{component}_{what}_total` (e.g., `http_requests_total`)
- **Gauges**: `{component}_{what}` (e.g., `memory_usage_bytes`)
- **Histograms**: `{component}_{what}_duration` (e.g., `http_request_duration_seconds`)
- **Units**: Use base units (seconds, bytes, not milliseconds or megabytes)

## Production Considerations

### Persistent Storage

For production, use PersistentVolumeClaim instead of EmptyDir:

```yaml
volumes:
  - name: prometheus-storage
    persistentVolumeClaim:
      claimName: prometheus-pvc
```

### Retention Policy

Adjust retention based on your needs:

```yaml
args:
  - '--storage.tsdb.retention.time=30d'  # Keep 30 days
  - '--storage.tsdb.retention.size=50GB'  # Or 50GB max
```

### High Availability

For HA, run multiple Prometheus replicas:

```yaml
spec:
  replicas: 2  # Multiple instances
```

Use Thanos or Cortex for:
- Global view across multiple Prometheus instances
- Long-term storage
- High availability

### Resource Limits

Adjust based on your scale:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

## Troubleshooting

### Target Not Scraping

1. **Check target status**: Visit http://localhost:9090/targets
2. **Verify service**: `kubectl get svc -n greenfield my-service`
3. **Check annotations**: `kubectl get deployment my-app -o yaml | grep prometheus`
4. **Test endpoint**: `curl http://my-service:8000/metrics`

### High Memory Usage

- **Reduce scrape interval**: Change `scrape_interval` to 30s or 60s
- **Limit retention**: Set `--storage.tsdb.retention.time=7d`
- **Drop metrics**: Use `metric_relabel_configs` to drop unused metrics
- **Increase resources**: Adjust memory limits

### Slow Queries

- **Use recording rules**: Pre-calculate expensive queries
- **Optimize PromQL**: Avoid high-cardinality queries
- **Limit time range**: Query shorter time windows
- **Use Grafana**: Better for visualization than Prometheus UI

### Missing Metrics

1. **Check if metric exists**: Search in Prometheus expression browser
2. **Verify scraping**: Check target is UP
3. **Check metric name**: Case-sensitive, check for typos
4. **Check labels**: Ensure label selectors match

## Further Reading

- [SLOs Documentation](../observability/slos.md) - Service Level Objectives
- [Alerts Documentation](../observability/alerts.md) - Alert rules and AlertManager
- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Best Practices](https://prometheus.io/docs/practices/)

