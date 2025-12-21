# Adding Custom SLOs

This guide explains how to add custom Service Level Objectives (SLOs) for your specific needs. The Greenfield Cluster provides a flexible framework for defining SLOs at different levels.

## Table of Contents

1. [Overview](#overview)
2. [Distribution SLOs](#distribution-slos)
3. [Service-Level SLOs](#service-level-slos)
4. [App/Pod-Level SLOs](#apppod-level-slos)
5. [Custom Business Metric SLOs](#custom-business-metric-slos)
6. [Best Practices](#best-practices)

## Overview

SLOs are defined using Prometheus recording rules that pre-calculate metrics. The general pattern is:

```yaml
- record: {scope}:{metric}:{aggregation}_{time_window}
  expr: |
    # PromQL expression
```

### SLO Components

Every SLO should have:
1. **Recording rule**: Pre-calculated metric
2. **Alert rule**: Fires when SLO is violated
3. **Grafana dashboard panel**: Visualization
4. **Documentation**: What it measures and why

## Distribution SLOs

Distribution SLOs track the distribution of values (latency, response sizes, etc.) using percentiles.

### Use Cases
- API response time (P50, P95, P99)
- Database query duration
- Message processing time
- File upload sizes

### Example: Custom Latency SLO

**Step 1: Define Recording Rule**

Edit `kustomize/base/observability/slos/application-slos.yaml`:

```yaml
- name: custom_latency_slos
  interval: 30s
  rules:
    # P50 latency for custom service
    - record: myapp:http_request:duration:p50_rate5m
      expr: |
        histogram_quantile(0.50,
          sum(rate(myapp_http_request_duration_seconds_bucket[5m]))
          by (service, endpoint, le)
        )
    
    # P95 latency for custom service
    - record: myapp:http_request:duration:p95_rate5m
      expr: |
        histogram_quantile(0.95,
          sum(rate(myapp_http_request_duration_seconds_bucket[5m]))
          by (service, endpoint, le)
        )
    
    # P99 latency for custom service
    - record: myapp:http_request:duration:p99_rate5m
      expr: |
        histogram_quantile(0.99,
          sum(rate(myapp_http_request_duration_seconds_bucket[5m]))
          by (service, endpoint, le)
        )
    
    # P99.9 latency for critical paths
    - record: myapp:http_request:duration:p999_rate5m
      expr: |
        histogram_quantile(0.999,
          sum(rate(myapp_http_request_duration_seconds_bucket[5m]))
          by (service, endpoint, le)
        )
```

**Step 2: Add Alert Rules**

Edit `kustomize/base/observability/alerts/application-alerts.yaml`:

```yaml
- alert: MyAppHighP95Latency
  expr: |
    myapp:http_request:duration:p95_rate5m > 0.5
  for: 10m
  labels:
    severity: warning
    component: myapp
    slo: latency
  annotations:
    summary: "MyApp P95 latency above 500ms"
    description: "MyApp P95 latency is {{ $value }}s (target: < 0.5s)"

- alert: MyAppHighP99Latency
  expr: |
    myapp:http_request:duration:p99_rate5m > 1.0
  for: 5m
  labels:
    severity: critical
    component: myapp
    slo: latency
  annotations:
    summary: "MyApp P99 latency above 1s"
    description: "MyApp P99 latency is {{ $value }}s (target: < 1s)"
```

**Step 3: Instrument Your Application**

In your application code (Python example):

```python
from prometheus_client import Histogram

# Define histogram with buckets appropriate for your use case
request_duration = Histogram(
    'myapp_http_request_duration_seconds',
    'HTTP request duration',
    ['service', 'endpoint'],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# In your request handler
with request_duration.labels(service='myapp', endpoint='/api/users').time():
    # Your code
    pass
```

## Service-Level SLOs

Service-level SLOs track request/response patterns for entire services.

### Use Cases
- API availability
- Success rate per endpoint
- Throughput (requests per second)
- Error rates by error type

### Example: Endpoint-Specific Success Rate

**Recording Rule:**

```yaml
- name: service_endpoint_slos
  interval: 30s
  rules:
    # Success rate per endpoint
    - record: myapp:http_requests:success_ratio_per_endpoint_rate5m
      expr: |
        sum(rate(myapp_http_requests_total{status!~"5.."}[5m]))
        by (service, endpoint)
        /
        sum(rate(myapp_http_requests_total[5m]))
        by (service, endpoint)
    
    # Error rate per error type
    - record: myapp:http_requests:error_ratio_by_type_rate5m
      expr: |
        sum(rate(myapp_http_requests_total{status=~"5.."}[5m]))
        by (service, endpoint, status)
        /
        sum(rate(myapp_http_requests_total[5m]))
        by (service, endpoint)
    
    # Requests per second per endpoint
    - record: myapp:http_requests:rps_per_endpoint_rate5m
      expr: |
        sum(rate(myapp_http_requests_total[5m]))
        by (service, endpoint)
```

**Alert Rule:**

```yaml
- alert: MyAppEndpointHighErrorRate
  expr: |
    myapp:http_requests:success_ratio_per_endpoint_rate5m < 0.95
    and
    myapp:http_requests:rps_per_endpoint_rate5m > 0.1
  for: 5m
  labels:
    severity: warning
    component: myapp
    slo: availability
  annotations:
    summary: "High error rate on {{ $labels.endpoint }}"
    description: "{{ $labels.service }}/{{ $labels.endpoint }} success rate: {{ $value | humanizePercentage }}"
```

## App/Pod-Level SLOs

App/Pod-level SLOs track resource usage and health at the application deployment level.

### Use Cases
- Pod restarts per application
- Memory usage per pod
- CPU throttling
- Container health

### Example: Application Restart Rate SLO

**Recording Rule:**

```yaml
- name: app_health_slos
  interval: 30s
  rules:
    # Pod restart rate per application
    - record: app:pod_restarts:rate1h
      expr: |
        rate(kube_pod_container_status_restarts_total[1h])
    
    # Pods in CrashLoopBackOff per app
    - record: app:pods:crashloop_count
      expr: |
        count(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"})
        by (namespace, pod)
    
    # Application uptime (time since last restart)
    - record: app:uptime:seconds
      expr: |
        time() - kube_pod_start_time
    
    # Pods not ready per application
    - record: app:pods:not_ready_count
      expr: |
        count(kube_pod_status_ready{condition="false"})
        by (namespace, pod)
```

**Alert Rule:**

```yaml
- alert: AppHighRestartRate
  expr: |
    sum(app:pod_restarts:rate1h) by (namespace, pod) > 0.5
  for: 15m
  labels:
    severity: warning
    component: application
    slo: stability
  annotations:
    summary: "Application {{ $labels.pod }} restarting frequently"
    description: "{{ $labels.pod }} in {{ $labels.namespace }} is restarting {{ $value }} times per hour"

- alert: AppInCrashLoop
  expr: |
    app:pods:crashloop_count > 0
  for: 5m
  labels:
    severity: critical
    component: application
    slo: stability
  annotations:
    summary: "Application {{ $labels.pod }} in CrashLoopBackOff"
    description: "{{ $labels.pod }} in {{ $labels.namespace }} is in CrashLoopBackOff state"
```

### Example: Resource Saturation SLO

**Recording Rule:**

```yaml
- name: app_resource_slos
  interval: 30s
  rules:
    # CPU saturation by application
    - record: app:cpu:saturation_by_app
      expr: |
        sum(rate(container_cpu_usage_seconds_total{container!=""}[5m]))
        by (namespace, app)
        /
        sum(container_spec_cpu_quota{container!=""}/container_spec_cpu_period{container!=""})
        by (namespace, app)
    
    # Memory saturation by application
    - record: app:memory:saturation_by_app
      expr: |
        sum(container_memory_working_set_bytes{container!=""})
        by (namespace, app)
        /
        sum(container_spec_memory_limit_bytes{container!=""})
        by (namespace, app)
    
    # Pods at resource limits
    - record: app:pods:at_limits_count
      expr: |
        count(
          (container_cpu_usage_seconds_total / container_spec_cpu_quota > 0.95)
          or
          (container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.95)
        ) by (namespace, app)
```

## Custom Business Metric SLOs

Business metric SLOs track domain-specific metrics that matter to your business.

### Use Cases
- Order success rate
- Payment processing time
- User registration flow completion
- Data processing throughput
- Queue depth

### Example: Order Processing SLO

**Step 1: Expose Business Metrics**

In your application:

```python
from prometheus_client import Counter, Histogram

# Order metrics
orders_total = Counter(
    'orders_total',
    'Total orders',
    ['status']  # success, failed, cancelled
)

order_processing_duration = Histogram(
    'order_processing_duration_seconds',
    'Order processing duration',
    ['order_type'],
    buckets=[0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0]
)

# In your order processing code
with order_processing_duration.labels(order_type='standard').time():
    result = process_order(order)
    
if result.success:
    orders_total.labels(status='success').inc()
else:
    orders_total.labels(status='failed').inc()
```

**Step 2: Define SLO Recording Rules**

```yaml
- name: business_slos
  interval: 30s
  rules:
    # Order success rate (SLO: 99.5%)
    - record: business:orders:success_ratio_rate5m
      expr: |
        sum(rate(orders_total{status="success"}[5m]))
        /
        sum(rate(orders_total[5m]))
    
    # Order success rate by type
    - record: business:orders:success_ratio_by_type_rate5m
      expr: |
        sum(rate(orders_total{status="success"}[5m])) by (order_type)
        /
        sum(rate(orders_total[5m])) by (order_type)
    
    # Order processing P95 latency (SLO: < 5s)
    - record: business:orders:processing_duration:p95_rate5m
      expr: |
        histogram_quantile(0.95,
          sum(rate(order_processing_duration_seconds_bucket[5m]))
          by (order_type, le)
        )
    
    # Order error budget remaining
    - record: business:orders:error_budget_remaining
      expr: |
        (0.005 - (1 - business:orders:success_ratio_rate30m)) / 0.005
    
    # Order throughput (orders per minute)
    - record: business:orders:throughput_per_minute
      expr: |
        sum(rate(orders_total[1m])) * 60
```

**Step 3: Add Alerts**

```yaml
- alert: OrderSuccessRateBelowSLO
  expr: |
    business:orders:success_ratio_rate5m < 0.995
    and
    sum(rate(orders_total[5m])) > 0.01
  for: 5m
  labels:
    severity: critical
    component: orders
    slo: success_rate
  annotations:
    summary: "Order success rate below 99.5% SLO"
    description: "Order success rate is {{ $value | humanizePercentage }} (target: > 99.5%)"

- alert: OrderProcessingSlowP95
  expr: |
    business:orders:processing_duration:p95_rate5m > 5
  for: 10m
  labels:
    severity: warning
    component: orders
    slo: latency
  annotations:
    summary: "Order processing P95 latency above 5s"
    description: "Order processing P95 is {{ $value }}s (target: < 5s)"

- alert: OrderErrorBudgetLow
  expr: |
    business:orders:error_budget_remaining < 0.1
  for: 5m
  labels:
    severity: warning
    component: orders
    slo: error_budget
  annotations:
    summary: "Order error budget nearly exhausted"
    description: "Only {{ $value | humanizePercentage }} of error budget remains"
```

### Example: Queue Depth SLO

```yaml
- name: queue_slos
  interval: 30s
  rules:
    # Queue depth (SLO: < 1000 messages)
    - record: business:queue:depth
      expr: |
        sum(queue_depth) by (queue_name)
    
    # Queue age (oldest message age in seconds)
    - record: business:queue:oldest_message_age_seconds
      expr: |
        max(queue_message_age_seconds) by (queue_name)
    
    # Queue processing rate (messages/sec)
    - record: business:queue:processing_rate
      expr: |
        rate(queue_messages_processed_total[5m])
```

## Best Practices

### 1. Start Simple

Begin with the four golden signals:
- **Latency**: How long does it take?
- **Traffic**: How much demand?
- **Errors**: How many requests fail?
- **Saturation**: How full are resources?

### 2. Choose Appropriate Time Windows

- **5m**: Real-time alerting, fast feedback
- **30m**: Error budget calculations
- **1h**: Trend analysis
- **1d**: Capacity planning

### 3. Use Consistent Naming

Follow the pattern: `{scope}:{metric}:{aggregation}_{time_window}`

Examples:
- `myapp:http_requests:success_ratio_rate5m`
- `business:orders:processing_duration:p95_rate5m`
- `app:cpu:saturation_by_app`

### 4. Set Realistic Targets

| SLO Target | Downtime per Month | Use Case |
|------------|-------------------|----------|
| 90% | 3 days | Development/testing |
| 95% | 1.5 days | Internal tools |
| 99% | 7.2 hours | Standard service |
| 99.5% | 3.6 hours | Important service |
| 99.9% | 43 minutes | Critical service |
| 99.95% | 21 minutes | Payment systems |
| 99.99% | 4 minutes | Life-critical systems |

### 5. Track Error Budgets

Error budgets help balance reliability and velocity:

```yaml
# Error budget for 99.9% SLO
- record: myapp:error_budget_remaining
  expr: |
    (0.001 - (1 - myapp:success_ratio_rate30m)) / 0.001
```

When error budget > 50%: Ship features  
When error budget < 10%: Focus on reliability

### 6. Alert on SLO Violations, Not Symptoms

**Bad** ❌:
```yaml
- alert: HighCPU
  expr: cpu_usage > 80%
```

**Good** ✅:
```yaml
- alert: LatencySLOViolation
  expr: myapp:http_request:duration:p95_rate5m > 1.0
```

### 7. Use Traffic Filters

Avoid false positives in low-traffic scenarios:

```yaml
expr: |
  myapp:success_ratio < 0.99
  and
  myapp:requests_rate5m > 0.1  # Only alert if traffic > 0.1 req/s
```

### 8. Document Your SLOs

For each SLO, document:
- **What**: What does it measure?
- **Why**: Why does it matter?
- **Target**: What's the target value?
- **Error Budget**: How much unreliability is acceptable?
- **Alerting**: When should we be notified?

### 9. Review and Iterate

- Monthly SLO review meetings
- Analyze SLO violations
- Adjust targets based on data
- Update runbooks with learnings

### 10. Multi-Window Multi-Burn-Rate Alerts

For critical SLOs, use multiple windows to catch both fast and slow burns:

```yaml
# Fast burn (critical) - 2% budget consumed in 1 hour
- alert: MyAppErrorBudgetFastBurn
  expr: |
    (
      myapp:success_ratio_rate5m < 0.98  # 2% error rate
      and
      myapp:success_ratio_rate1h < 0.98
    )
  for: 2m
  labels:
    severity: critical

# Slow burn (warning) - consuming budget steadily
- alert: MyAppErrorBudgetSlowBurn
  expr: |
    (
      myapp:success_ratio_rate30m < 0.995  # 0.5% error rate
      and
      myapp:success_ratio_rate6h < 0.995
    )
  for: 15m
  labels:
    severity: warning
```

## Testing Your SLOs

### 1. Simulate Load

```bash
# Generate traffic
for i in {1..1000}; do
  curl http://myapp/api/endpoint
done
```

### 2. Introduce Errors

```bash
# Call error endpoint
for i in {1..10}; do
  curl http://myapp/api/error-endpoint
done
```

### 3. Check Metrics

```bash
# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=myapp:success_ratio_rate5m'
```

### 4. Verify Alerts

Check Prometheus alerts page or AlertManager to see if alerts fire as expected.

## Example: Complete SLO Implementation

Here's a complete example for a payment service:

**Recording Rules:**

```yaml
- name: payment_slos
  interval: 30s
  rules:
    # Success rate (target: 99.95%)
    - record: payment:transactions:success_ratio_rate5m
      expr: |
        sum(rate(payment_transactions_total{status="success"}[5m]))
        /
        sum(rate(payment_transactions_total[5m]))
    
    # P99 latency (target: < 2s)
    - record: payment:transactions:duration:p99_rate5m
      expr: |
        histogram_quantile(0.99,
          sum(rate(payment_transaction_duration_seconds_bucket[5m]))
          by (payment_method, le)
        )
    
    # Error budget (0.05% allowed)
    - record: payment:transactions:error_budget_remaining
      expr: |
        (0.0005 - (1 - payment:transactions:success_ratio_rate30m)) / 0.0005
```

**Alerts:**

```yaml
- alert: PaymentSuccessRateCritical
  expr: |
    payment:transactions:success_ratio_rate5m < 0.9995
    and
    sum(rate(payment_transactions_total[5m])) > 0.01
  for: 2m
  labels:
    severity: critical
    component: payment
    slo: success_rate
  annotations:
    summary: "Payment success rate below 99.95%"
    description: "Success rate: {{ $value | humanizePercentage }}"
    runbook_url: "https://wiki.example.com/runbooks/payment-slo-violation"

- alert: PaymentLatencyHigh
  expr: |
    payment:transactions:duration:p99_rate5m > 2
  for: 5m
  labels:
    severity: warning
    component: payment
    slo: latency
  annotations:
    summary: "Payment P99 latency above 2s"
    description: "P99 latency: {{ $value }}s"
```

**Grafana Dashboard Panel:**

```json
{
  "title": "Payment Success Rate vs SLO",
  "targets": [
    {
      "expr": "payment:transactions:success_ratio_rate5m * 100",
      "legendFormat": "Success Rate"
    },
    {
      "expr": "99.95",
      "legendFormat": "SLO Target (99.95%)"
    }
  ],
  "yaxis": {
    "min": 99.9,
    "max": 100
  }
}
```

## Further Reading

- [SLOs Guide](slos.md) - Understanding Service Level Objectives
- [Alerts Guide](alerts.md) - Alert rules and AlertManager
- [Prometheus Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Google SRE Workbook - Implementing SLOs](https://sre.google/workbook/implementing-slos/)
