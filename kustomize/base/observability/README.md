# Observability SLOs and Alerting

This directory contains Service Level Objectives (SLOs), recording rules, and alerting configurations for the Greenfield Cluster.

## Overview

The observability layer provides:

1. **SLO Recording Rules** - Pre-calculated metrics for cluster and application SLOs
2. **Alert Rules** - Environment-aware alerts based on SLO violations
3. **AlertManager** - Intelligent alert routing and grouping (optional)

## Components

### SLOs (`slos/`)

#### Cluster-Level SLOs
- **API Server Availability**: 99.9% target
- **Node Health**: 99% nodes ready
- **Pod Scheduling Success**: 99% success rate
- **Resource Utilization**: CPU, Memory, Disk metrics

#### Application-Level SLOs
- **Request Success Rate**: 99.9% (0.1% error budget)
- **Latency**: P50, P95, P99 percentiles
- **Traffic Volume**: Request rates
- **Saturation**: CPU and memory usage per pod

### Alerts (`alerts/`)

#### Cluster Alerts
- API Server availability violations
- Node health issues
- Pod scheduling failures
- Resource exhaustion warnings

#### Application Alerts
- Error budget exhaustion
- High error rates (5% warning, 10% critical)
- High latency (P95 > 1s warning, > 5s critical)
- Pod resource saturation
- Application down

### AlertManager (`alertmanager/`)

Optional AlertManager deployment with:
- Environment-aware routing (production vs. non-production)
- Low-traffic environment handling
- Alert inhibition rules to prevent storms
- Multiple receiver configurations

## Usage

### 1. Including in Your Deployment

The observability module is included by default in the base kustomization. To customize, edit `kustomize/base/kustomization.yaml`:

```yaml
resources:
  - observability  # Include SLOs and alerts
```

### 2. Enabling AlertManager

By default, AlertManager is commented out to be optional. To enable it:

Edit `kustomize/base/observability/kustomization.yaml`:

```yaml
resources:
  - slos
  - alerts
  - alertmanager  # Uncomment this line
```

### 3. Configuring AlertManager Receivers

Edit `alertmanager/configmap.yaml` to configure notification channels:

```yaml
# Example: Slack notifications
receivers:
  - name: 'critical-production'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
        title: '[CRITICAL] {{ .GroupLabels.alertname }}'
```

Supported receivers:
- Slack
- PagerDuty
- Email
- Webhook
- OpsGenie
- VictorOps

### 4. Environment-Specific Configuration

#### Development Environment

For dev environments with low traffic, alerts are automatically suppressed when:
- Traffic rate is below 0.01 req/s (tracked by `LowTrafficEnvironment` alert)
- This prevents false positives from SLO violations during idle periods

Configure in overlay:

```yaml
# kustomize/overlays/dev/prometheus-config-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: greenfield-dev
data:
  alertmanager.yml: |
    route:
      receiver: 'low-traffic'  # All alerts go to low-priority channel
```

#### Production Environment

Production environments use strict thresholds with immediate notifications:

```yaml
# kustomize/overlays/prod/alertmanager-config-patch.yaml
- match:
    severity: critical
    environment: production
  receiver: 'critical-production'
  group_wait: 10s
  repeat_interval: 1h
```

## Updating Prometheus Configuration

To use these SLO rules and alerts, update your Prometheus configuration:

```yaml
# prometheus/configmap.yaml
rule_files:
  - /etc/prometheus/rules/*.yml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093
```

Mount the SLO and alert ConfigMaps as volumes in the Prometheus deployment.

## Metrics Reference

### SLO Recording Rules

| Metric | Description | Target |
|--------|-------------|--------|
| `apiserver:availability:ratio_rate5m` | API server success rate (5m) | > 99.9% |
| `node:health:ratio` | Percentage of healthy nodes | > 99% |
| `http:requests:success_ratio_rate5m` | Application success rate (5m) | > 99.9% |
| `http:requests:error_budget_remaining` | Remaining error budget | > 0 |
| `http:request:duration:p95_rate5m` | P95 latency (5m) | < 1s |

### Alert Labels

All alerts include:
- `severity`: `critical`, `warning`, or `info`
- `component`: affected component (e.g., `apiserver`, `application`)
- `slo`: related SLO (e.g., `availability`, `latency`)

## Best Practices

1. **Start with defaults**: The provided SLOs are industry-standard starting points
2. **Tune for your workload**: Adjust thresholds based on your application requirements
3. **Use error budgets**: Monitor error budget consumption to balance reliability and velocity
4. **Environment separation**: Use different alert severity/routing for dev vs. prod
5. **Alert on symptoms**: Focus on user-facing issues (error rate, latency) not implementation details
6. **Review regularly**: Periodically review alert frequency and adjust thresholds

## Monitoring the Monitors

To ensure your observability stack is working:

```bash
# Check Prometheus is scraping SLO metrics
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check AlertManager is receiving alerts
kubectl port-forward -n greenfield svc/alertmanager 9093:9093
# Visit: http://localhost:9093/#/alerts

# View Prometheus rules
curl http://localhost:9090/api/v1/rules
```

## Troubleshooting

### Alerts not firing

1. Check Prometheus is loading the rules:
   ```bash
   kubectl logs -n greenfield deployment/prometheus | grep "rules"
   ```

2. Verify metrics exist:
   ```bash
   # Port-forward and query
   curl 'http://localhost:9090/api/v1/query?query=http:requests:success_ratio_rate5m'
   ```

### Too many false positives

- Enable low-traffic detection for non-production environments
- Adjust thresholds in alert rules
- Increase `for` duration to require sustained violations

### Missing notifications

1. Check AlertManager logs:
   ```bash
   kubectl logs -n greenfield deployment/alertmanager
   ```

2. Test receiver configuration:
   ```bash
   # Send test alert
   curl -X POST http://localhost:9093/api/v1/alerts
   ```

## Further Reading

- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [SRE Book - Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
