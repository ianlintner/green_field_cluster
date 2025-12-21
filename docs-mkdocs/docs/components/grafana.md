# Grafana

Grafana is an open-source analytics and monitoring platform used in the Greenfield Cluster for visualizing metrics and creating dashboards.

## Overview

Grafana in the Greenfield Cluster provides:

- **Metrics Visualization**: Beautiful, customizable dashboards
- **Multiple Data Sources**: Prometheus, Jaeger, and more
- **Alerting**: Visual alert rules and notifications
- **Pre-built Dashboards**: SLO and component monitoring
- **User Management**: Role-based access control

## Architecture

### Configuration

| Parameter | Default Value |
|-----------|---------------|
| **Version** | Latest |
| **Default Login** | admin / admin123 |
| **Port** | 3000 |
| **CPU Request** | 100m |
| **Memory Request** | 256Mi |
| **Persistent Storage** | Yes |

## Usage

### Accessing Grafana

```bash
# Port forward to Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000

# Open in browser
http://localhost:3000

# Default credentials (CHANGE IN PRODUCTION!)
Username: admin
Password: admin123
```

### Data Sources

Grafana is pre-configured with:

1. **Prometheus**: Metrics data source
2. **Jaeger**: Distributed tracing
3. **Loki**: Log aggregation (if enabled)

### Pre-built Dashboards

The cluster includes dashboards for:

- **Cluster Health SLOs**: Overall cluster health metrics
- **Application SLOs**: Application-level SLO tracking
- **Component Metrics**: Individual component dashboards
- **Resource Usage**: CPU, memory, disk usage
- **Network Traffic**: Service mesh traffic patterns

## Creating Dashboards

### Basic Dashboard

1. Click "+" → "Dashboard"
2. Add new panel
3. Select Prometheus data source
4. Write PromQL query:

```promql
# CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Request rate
rate(http_requests_total[5m])
```

### Example Dashboard JSON

```json
{
  "dashboard": {
    "title": "My Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ]
      }
    ]
  }
}
```

## Alerting

### Creating Alerts

1. Navigate to Alerting → Alert rules
2. Create new alert rule
3. Define query and thresholds
4. Configure notification channels

### Example Alert

```yaml
# Alert if API error rate > 5%
expr: |
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
  > 0.05
```

## Best Practices

1. **Organize Dashboards**: Use folders to organize by service/team
2. **Use Variables**: Make dashboards dynamic with template variables
3. **Set Refresh Rates**: Appropriate intervals based on data freshness
4. **Alert Fatigue**: Avoid too many alerts, focus on actionable items
5. **Dashboard as Code**: Export and version control dashboard JSON

## Advanced Features

### Variables

Create dynamic dashboards with variables:

```
# Namespace variable
Query: label_values(kube_pod_info, namespace)

# Pod variable
Query: label_values(kube_pod_info{namespace="$namespace"}, pod)
```

### Annotations

Add event annotations to graphs:

- Deployments
- Alerts
- Incidents
- Releases

## Monitoring

```bash
# Check Grafana status
kubectl get pods -n greenfield -l app=grafana

# View logs
kubectl logs -n greenfield deployment/grafana

# Check persistence
kubectl get pvc -n greenfield | grep grafana
```

## Additional Resources

- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Component](prometheus.md)
- [Jaeger Component](jaeger.md)
- [SLOs Guide](../observability/slos.md)
