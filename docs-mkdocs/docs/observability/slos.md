# Service Level Objectives (SLOs)

Service Level Objectives (SLOs) are target values or ranges for service level indicators (SLIs) that define the reliability goals for your services. This guide covers the SLO framework implemented in Greenfield Cluster.

## Overview

The Greenfield Cluster includes pre-configured SLOs for both cluster-level infrastructure and application-level performance metrics. These SLOs follow industry best practices and are based on Google's SRE principles.

## Why SLOs Matter

SLOs help you:

- **Balance reliability and velocity**: Know when you can move fast vs. when to focus on stability
- **Make data-driven decisions**: Objective metrics for reliability discussions
- **Avoid alert fatigue**: Alert only when SLOs are violated, not on every anomaly
- **Calculate error budgets**: Track how much unreliability you can "spend" on new features

## Cluster-Level SLOs

### API Server Availability

**Target**: 99.9% (three nines)

**Metric**: `apiserver:availability:ratio_rate5m`

**Definition**: Percentage of API server requests that succeed (non-5xx responses)

```promql
# Recording rule
apiserver:availability:ratio_rate5m = 
  sum(rate(apiserver_request_total{code!~"5.."}[5m]))
  /
  sum(rate(apiserver_request_total[5m]))
```

**Why it matters**: The API server is the control plane heart. Low availability impacts cluster operations, deployments, and scaling.

**Error budget**: 0.1% = ~43 minutes of downtime per month

### Node Health

**Target**: 99% nodes ready

**Metric**: `node:health:ratio`

**Definition**: Percentage of nodes in Ready state

```promql
node:health:ratio = 
  sum(kube_node_status_condition{condition="Ready",status="true"})
  /
  sum(kube_node_status_condition{condition="Ready"})
```

**Why it matters**: Node health directly impacts workload capacity and resilience.

### Pod Scheduling Success

**Target**: 99% success rate

**Metric**: `pod:scheduling:success_ratio_rate5m`

**Definition**: Percentage of pods successfully scheduled

```promql
pod:scheduling:success_ratio_rate5m = 
  sum(rate(kube_pod_status_scheduled{condition="true"}[5m]))
  /
  sum(rate(kube_pod_status_scheduled[5m]))
```

**Why it matters**: Scheduling failures indicate resource pressure or configuration issues.

### Resource Utilization

**CPU Target**: < 90% utilization  
**Memory Target**: < 85% utilization  
**Disk Target**: < 80% utilization

**Metrics**:
- `cluster:cpu:utilization`
- `cluster:memory:utilization`
- `cluster:disk:utilization`

**Why it matters**: High utilization leads to performance degradation and reduced resilience.

## Application-Level SLOs

### Request Success Rate (Availability)

**Target**: 99.9% (three nines)

**Metric**: `http:requests:success_ratio_rate5m`

**Definition**: Percentage of HTTP requests that succeed (non-5xx responses)

```promql
http:requests:success_ratio_rate5m = 
  sum(rate(http_requests_total{status!~"5.."}[5m])) by (app, namespace)
  /
  sum(rate(http_requests_total[5m])) by (app, namespace)
```

**Error budget**: 0.1% = ~43 minutes of errors per month

**Dashboard**: Shows success rate per application with SLO target line

### Request Latency

**P95 Target**: < 1 second (warning), < 5 seconds (critical)  
**P99 Target**: < 2 seconds (warning), < 10 seconds (critical)

**Metrics**:
- `http:request:duration:p50_rate5m`
- `http:request:duration:p95_rate5m`
- `http:request:duration:p99_rate5m`

**Definition**: 95th and 99th percentile of request duration

```promql
http:request:duration:p95_rate5m = 
  histogram_quantile(0.95, 
    sum(rate(http_request_duration_seconds_bucket[5m])) 
    by (app, namespace, le)
  )
```

**Why it matters**: Latency directly impacts user experience. High latency = frustrated users.

### Error Budget

**Metric**: `http:requests:error_budget_remaining`

**Definition**: Percentage of error budget remaining for the current period

```promql
http:requests:error_budget_remaining = 
  (0.001 - (1 - http:requests:success_ratio_rate30m)) / 0.001
```

**Interpretation**:
- 100% = No errors, full budget available
- 50% = Half the error budget consumed
- 0% = Error budget exhausted
- < 0% = Exceeded error budget

**Use case**: When error budget is low (< 10%), focus on reliability over new features.

### Traffic Volume

**Metric**: `http:requests:rate5m`

**Definition**: Request rate in requests per second

```promql
http:requests:rate5m = 
  sum(rate(http_requests_total[5m])) by (app, namespace)
```

**Why it matters**: 
- Baseline for capacity planning
- Low traffic environments (< 0.01 req/s) get relaxed alerting
- Sudden drops may indicate outages

### Saturation (Resource Usage)

**CPU Target**: < 90% (warning), < 95% (critical)  
**Memory Target**: < 85% (warning), < 95% (critical)

**Metrics**:
- `pod:cpu:saturation`
- `pod:memory:saturation`

**Definition**: Pod resource usage as percentage of limits

```promql
pod:cpu:saturation = 
  sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace)
  /
  sum(container_spec_cpu_quota/container_spec_cpu_period) by (pod, namespace)
```

**Why it matters**: High saturation leads to throttling (CPU) or OOM kills (memory).

## SLO Time Windows

Different time windows serve different purposes:

### 5-minute window (fast feedback)
- **Use for**: Real-time alerting
- **Examples**: `*_rate5m` metrics
- **Tradeoff**: Sensitive to short-term fluctuations

### 30-minute window (balanced)
- **Use for**: Error budget calculations
- **Examples**: `*_rate30m` metrics
- **Tradeoff**: Balances sensitivity and stability

### 1-hour window (stable)
- **Use for**: Trend analysis, capacity planning
- **Examples**: `*_rate1h` metrics
- **Tradeoff**: Slower to detect issues, but noise-resistant

## Viewing SLOs

### Grafana Dashboards

Two dashboards are included:

1. **Cluster Health SLOs** (`/d/cluster-health-slo`)
   - API server availability
   - Node health ratio
   - Resource utilization
   - Pod scheduling success

2. **Application SLOs** (`/d/application-slo`)
   - Success rate by app
   - Error budget remaining
   - Latency percentiles (P95, P99)
   - Request rate
   - Pod saturation

Access Grafana:
```bash
kubectl port-forward -n greenfield svc/grafana 3000:3000
# Visit: http://localhost:3000
```

### Prometheus Queries

Query SLO metrics directly in Prometheus:

```bash
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Visit: http://localhost:9090
```

Example queries:

```promql
# Current API server availability
apiserver:availability:ratio_rate5m * 100

# Error budget remaining by app
http:requests:error_budget_remaining * 100

# P95 latency by app
http:request:duration:p95_rate5m
```

## Customizing SLOs

### Adjusting Targets

Edit the recording rules in `kustomize/base/observability/slos/`:

```yaml
# Example: Change API server SLO to 99.5%
- record: apiserver:availability:ratio_rate5m
  expr: |
    sum(rate(apiserver_request_total{code!~"5.."}[5m]))
    /
    sum(rate(apiserver_request_total[5m]))
```

Then update corresponding alerts in `kustomize/base/observability/alerts/`.

### Adding Custom SLOs

1. Add recording rule to appropriate ConfigMap
2. Create corresponding alert rule
3. Update Grafana dashboard
4. Document your SLO

Example custom SLO:

```yaml
# Custom: Database query success rate
- record: db:queries:success_ratio_rate5m
  expr: |
    sum(rate(db_queries_total{status="success"}[5m])) by (database)
    /
    sum(rate(db_queries_total[5m])) by (database)
```

## Best Practices

### 1. Start with Defaults

The provided SLOs are battle-tested defaults. Use them as-is initially, then tune based on your actual usage.

### 2. Set Achievable Targets

**Don't**: Set 99.99% SLOs for everything (four nines is very hard!)  
**Do**: Start with 99% or 99.9%, adjust based on user needs

### 3. Use Error Budgets

When error budget is healthy (> 50%):
- ✅ Deploy new features
- ✅ Experiment with new technologies
- ✅ Take reasonable risks

When error budget is low (< 10%):
- ❌ Freeze new features
- ✅ Focus on reliability
- ✅ Investigate root causes

### 4. Review Regularly

Monthly SLO review:
- Are we meeting targets?
- Are targets still relevant?
- What consumed error budget?
- What can we improve?

### 5. Environment-Specific Targets

- **Production**: Strict SLOs (99.9%)
- **Staging**: Moderate SLOs (99%)
- **Development**: Relaxed SLOs (95%)

### 6. Don't Over-Alert

Alert on:
- ✅ SLO violations
- ✅ Error budget exhaustion
- ✅ Symptoms (latency, errors)

Don't alert on:
- ❌ Individual failures (within error budget)
- ❌ Causes (disk usage, unless critical)
- ❌ Everything (alert fatigue)

## Troubleshooting

### SLO Metric Not Showing

**Check**: Prometheus is scraping your application

```bash
# Check targets
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Visit: http://localhost:9090/targets
```

**Ensure**: Your application exposes metrics in Prometheus format

### Alert Not Firing

**Check**: Recording rule is evaluated

```bash
# Query the recording rule metric
curl 'http://localhost:9090/api/v1/query?query=http:requests:success_ratio_rate5m'
```

**Check**: Alert query matches data

```bash
# Test alert query manually
(1 - http:requests:success_ratio_rate5m) > 0.05
```

### False Positive Alerts

**Option 1**: Increase `for` duration

```yaml
for: 10m  # Require 10 minutes of violation
```

**Option 2**: Adjust threshold

```yaml
expr: http:requests:success_ratio_rate5m < 0.98  # Relax from 0.999
```

**Option 3**: Enable low-traffic detection (see [Alerts documentation](alerts.md))

## Further Reading

- [Alerting Guide](alerts.md) - Alert rules and AlertManager configuration
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Google SRE Book - SLO Chapter](https://sre.google/sre-book/service-level-objectives/)
- [SLO Workshop](https://sre.google/workbook/implementing-slos/)
