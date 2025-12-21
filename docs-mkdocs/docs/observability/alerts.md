# Alerting

This guide covers the alerting system in Greenfield Cluster, including alert rules, AlertManager configuration, and environment-aware alerting strategies.

## Overview

The Greenfield Cluster alerting system:

- **SLO-based alerts**: Alerts fire when Service Level Objectives are violated
- **Environment-aware**: Different thresholds and routing for dev/staging/prod
- **Low-traffic handling**: Automatic suppression in low-traffic environments
- **Alert grouping**: Intelligent grouping to prevent alert storms
- **Optional AlertManager**: Can use built-in routing or integrate with external systems

## Alert Categories

### Cluster Health Alerts

Critical alerts for cluster infrastructure:

#### APIServerAvailabilityBelowSLO
**Severity**: Critical  
**Threshold**: API server availability < 99.9%  
**Duration**: 5 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

```promql
apiserver:availability:ratio_rate5m < 0.999
and
on() (sum(rate(apiserver_request_total[5m])) > 0.1)
```

**Impact**: Cluster control plane issues, deployments may fail  
**Action**: Check API server logs, verify etcd health

#### NodeNotReady
**Severity**: Critical  
**Threshold**: Node Ready condition is false  
**Duration**: 5 minutes

**Impact**: Reduced cluster capacity, workloads may be evicted  
**Action**: SSH to node, check kubelet logs, verify network connectivity

#### HighClusterCPUUtilization
**Severity**: Critical  
**Threshold**: CPU utilization > 90%  
**Duration**: 15 minutes

**Impact**: Performance degradation, throttling  
**Action**: Scale cluster, optimize workloads, review resource requests

#### HighClusterMemoryUtilization
**Severity**: Warning  
**Threshold**: Memory utilization > 85%  
**Duration**: 15 minutes

**Impact**: Risk of OOM kills  
**Action**: Scale cluster, identify memory-hungry pods

#### PVCAlmostFull
**Severity**: Critical  
**Threshold**: PVC usage > 90%  
**Duration**: 5 minutes

**Impact**: Application may fail to write data  
**Action**: Expand PVC, clean up old data, implement log rotation

### Application Alerts

Performance and reliability alerts:

#### ApplicationErrorBudgetExhausted
**Severity**: Critical  
**Threshold**: Error budget remaining < 10%  
**Duration**: 5 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

```promql
http:requests:error_budget_remaining < 0.1
and
http:requests:rate5m > 0.1
```

**Impact**: Service reliability at risk, user experience degraded  
**Action**: Stop deployments, investigate error sources, rollback if needed

#### HighApplicationErrorRate
**Severity**: Warning  
**Threshold**: Error rate > 5%  
**Duration**: 5 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

**Impact**: Users experiencing errors  
**Action**: Check logs, recent deployments, dependencies

#### VeryHighApplicationErrorRate
**Severity**: Critical  
**Threshold**: Error rate > 10%  
**Duration**: 3 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

**Impact**: Major service degradation  
**Action**: Immediate rollback, incident response

#### HighApplicationLatencyP95
**Severity**: Warning  
**Threshold**: P95 latency > 1 second  
**Duration**: 10 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

**Impact**: Slow user experience  
**Action**: Check database queries, cache hit rate, downstream services

#### VeryHighApplicationLatencyP95
**Severity**: Critical  
**Threshold**: P95 latency > 5 seconds  
**Duration**: 5 minutes  
**Traffic filter**: Only fires if request rate > 0.1 req/s

**Impact**: Severely degraded user experience  
**Action**: Immediate investigation, scale resources, optimize queries

#### HighPodCPUSaturation
**Severity**: Warning  
**Threshold**: Pod CPU saturation > 90%  
**Duration**: 15 minutes

**Impact**: CPU throttling, slow performance  
**Action**: Increase CPU limits, scale horizontally

#### VeryHighPodMemorySaturation
**Severity**: Critical  
**Threshold**: Pod memory saturation > 95%  
**Duration**: 5 minutes

**Impact**: Imminent OOM kill  
**Action**: Increase memory limits immediately, investigate memory leak

#### ApplicationDown
**Severity**: Critical  
**Threshold**: Application not responding  
**Duration**: 2 minutes

**Impact**: Complete service outage  
**Action**: Check pod status, recent changes, restart if needed

## Environment-Aware Alerting

### Development Environment

**Characteristics**:
- Low traffic (often < 0.01 req/s)
- Frequent deployments
- Acceptable downtime

**Alerting strategy**:
```yaml
# Relaxed timing
group_wait: 30m
repeat_interval: 24h

# Only critical issues alert
routes:
  - match:
      severity: critical
    receiver: 'dev-critical'
    group_wait: 15m
  - match:
      severity: warning
    receiver: 'dev-low-priority'  # Often just logging
```

**Low-traffic suppression**:
```yaml
# Silence alerts when traffic is very low
inhibit_rules:
  - source_match:
      traffic: low  # Set by LowTrafficEnvironment alert
    target_match_re:
      alertname: '.*'
```

### Staging Environment

**Characteristics**:
- Moderate traffic
- Pre-production testing
- Some tolerance for issues

**Alerting strategy**:
```yaml
group_wait: 10m
repeat_interval: 12h

# Balanced approach
routes:
  - match:
      severity: critical
    receiver: 'staging-critical'
  - match:
      severity: warning
    receiver: 'staging-warning'
```

### Production Environment

**Characteristics**:
- High traffic
- Zero tolerance for downtime
- Direct user impact

**Alerting strategy**:
```yaml
# Immediate alerting
group_wait: 10s
repeat_interval: 1h

# Multiple channels for critical
routes:
  - match:
      severity: critical
    receiver: 'prod-critical'  # Slack + PagerDuty
  - match:
      severity: warning
    receiver: 'prod-warning'   # Slack only
```

## AlertManager Configuration

### Enabling AlertManager

1. Edit `kustomize/base/observability/kustomization.yaml`:

```yaml
resources:
  - slos
  - alerts
  - alertmanager  # Uncomment this line
```

2. Apply the configuration:

```bash
kubectl apply -k kustomize/base/
```

3. Verify AlertManager is running:

```bash
kubectl get pods -n greenfield -l app=alertmanager
```

### Configuring Receivers

Edit `kustomize/base/observability/alertmanager/configmap.yaml`:

#### Slack Integration

```yaml
receivers:
  - name: 'prod-critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts-critical'
        title: ':fire: [{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}'
        text: |
          *Severity:* {{ .GroupLabels.severity }}
          *Summary:* {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}
          *Description:* {{ range .Alerts }}{{ .Annotations.description }}{{ end }}
        send_resolved: true
```

#### PagerDuty Integration

```yaml
receivers:
  - name: 'prod-critical'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_INTEGRATION_KEY'
        description: '{{ .GroupLabels.alertname }}'
        details:
          severity: '{{ .GroupLabels.severity }}'
          summary: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

#### Email Integration

```yaml
receivers:
  - name: 'prod-critical'
    email_configs:
      - to: 'oncall@example.com'
        from: 'alertmanager@example.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alertmanager@example.com'
        auth_password: 'YOUR_APP_PASSWORD'
        headers:
          Subject: '[CRITICAL] {{ .GroupLabels.alertname }}'
```

#### Webhook Integration

```yaml
receivers:
  - name: 'prod-critical'
    webhook_configs:
      - url: 'https://your-webhook-endpoint.com/alerts'
        send_resolved: true
```

### Alert Routing

Route different alerts to different receivers:

```yaml
route:
  receiver: 'default'
  routes:
    # Database alerts to DBA team
    - match:
        component: database
      receiver: 'dba-team'
    
    # Security alerts to security team
    - match:
        component: security
      receiver: 'security-team'
    
    # Application alerts to dev team
    - match:
        component: application
      receiver: 'dev-team'
```

### Alert Grouping

Group related alerts to reduce noise:

```yaml
route:
  # Group by these labels
  group_by: ['alertname', 'namespace', 'service']
  
  # Wait 10s before sending first notification
  # (allows grouping of simultaneous alerts)
  group_wait: 10s
  
  # Wait 10s before sending additional alerts
  # to an existing group
  group_interval: 10s
  
  # Re-send grouped alerts every 4 hours
  repeat_interval: 4h
```

### Inhibition Rules

Prevent alert storms by silencing dependent alerts:

```yaml
inhibit_rules:
  # Don't alert on pod issues if node is down
  - source_match:
      alertname: 'NodeNotReady'
    target_match_re:
      alertname: '(HighPod.*|ApplicationDown)'
    equal: ['node']
  
  # Don't alert on SLO violations if app is down
  - source_match:
      alertname: 'ApplicationDown'
    target_match_re:
      alertname: '(HighApplicationErrorRate|HighApplicationLatencyP95)'
    equal: ['job', 'namespace']
  
  # Suppress warnings when critical alert is firing
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace', 'pod']
```

## Low-Traffic Environment Handling

For dev/staging environments with sporadic traffic:

### LowTrafficEnvironment Alert

```yaml
- alert: LowTrafficEnvironment
  expr: |
    http:requests:rate5m < 0.01
  for: 30m
  labels:
    severity: info
    traffic: low
```

This alert fires when traffic is very low (< 0.01 req/s), adding the `traffic: low` label.

### Using Low-Traffic Label

Inhibit other alerts in low-traffic environments:

```yaml
inhibit_rules:
  - source_match:
      traffic: low
    target_match_re:
      alertname: '(.*ErrorRate|.*Latency|ErrorBudget).*'
    equal: ['namespace', 'app']
```

This prevents SLO violation alerts when there's no meaningful traffic.

## Testing Alerts

### Manual Alert Testing

1. Port-forward to AlertManager:
```bash
kubectl port-forward -n greenfield svc/alertmanager 9093:9093
```

2. Send test alert:
```bash
curl -X POST http://localhost:9093/api/v1/alerts -H 'Content-Type: application/json' -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test-instance"
    },
    "annotations": {
      "summary": "Test alert",
      "description": "This is a test alert"
    }
  }
]'
```

3. Check AlertManager UI:
```
http://localhost:9093/#/alerts
```

### Simulating Alert Conditions

#### High Error Rate
```bash
# Generate errors in your application
for i in {1..100}; do
  curl http://your-app/endpoint-that-returns-500
done
```

#### High Latency
```bash
# Add artificial delay to your application
# or query a slow endpoint repeatedly
```

#### Resource Saturation
```bash
# Use stress tool in a pod
kubectl run stress --image=polinux/stress --restart=Never -- stress --cpu 4 --timeout 600s
```

## Monitoring AlertManager

### Check AlertManager Status

```bash
# Health endpoint
curl http://localhost:9093/-/healthy

# Ready endpoint
curl http://localhost:9093/-/ready

# Configuration
curl http://localhost:9093/api/v1/status
```

### View Active Alerts

```bash
# Via API
curl http://localhost:9093/api/v1/alerts | jq

# Via UI
# Visit: http://localhost:9093/#/alerts
```

### Check Alert History

AlertManager doesn't store history. For historical data:

1. Query Prometheus alerts:
```promql
ALERTS{alertname="YourAlert"}
```

2. Use Grafana to visualize alert history

3. Store alerts in external system (e.g., webhook to database)

## Silencing Alerts

### Temporary Silence (Maintenance)

During maintenance windows, silence alerts:

```bash
# Via API
curl -X POST http://localhost:9093/api/v1/silences -H 'Content-Type: application/json' -d '{
  "matchers": [
    {
      "name": "alertname",
      "value": "NodeNotReady",
      "isRegex": false
    }
  ],
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T02:00:00Z",
  "createdBy": "admin",
  "comment": "Planned maintenance"
}'
```

### Permanent Silence (Configuration)

Edit alert rules to add exceptions:

```yaml
- alert: MyAlert
  expr: my_metric > threshold
    unless
    on() (some_maintenance_metric > 0)
```

## Best Practices

### 1. Alert on Symptoms, Not Causes

**Do**:
- ✅ Alert on high error rate (symptom)
- ✅ Alert on high latency (symptom)
- ✅ Alert on SLO violations (symptom)

**Don't**:
- ❌ Alert on disk usage (unless critical)
- ❌ Alert on CPU usage (unless critical)
- ❌ Alert on every log error

### 2. Make Alerts Actionable

Every alert should have:
- Clear summary
- Detailed description
- Runbook URL
- Suggested actions

```yaml
annotations:
  summary: "API Server availability below SLO"
  description: "Availability is {{ $value | humanizePercentage }}"
  runbook_url: "https://github.com/org/repo/docs/runbooks/apiserver.md"
  action: "Check API server logs and etcd health"
```

### 3. Tune Alert Thresholds

Monitor alert frequency:
- Too many alerts = fatigue, thresholds too strict
- Too few alerts = issues missed, thresholds too relaxed

Review monthly and adjust.

### 4. Use Different Severities

- **Critical**: Immediate action required, user impact
- **Warning**: Investigation needed, no immediate user impact
- **Info**: Informational only, no action required

### 5. Test Your Alerts

- Regularly trigger test alerts
- Verify notifications reach the right people
- Ensure runbooks are up-to-date
- Practice incident response

### 6. Document Alert Response

Create runbooks for common alerts:
- What does this alert mean?
- What is the user impact?
- How do I investigate?
- How do I fix it?
- How do I prevent it?

## Troubleshooting

### Alert Not Firing

1. **Check Prometheus has data**:
```bash
curl 'http://localhost:9090/api/v1/query?query=your_metric'
```

2. **Check alert rule syntax**:
```bash
kubectl logs -n greenfield deployment/prometheus | grep -i error
```

3. **Check alert query**:
```bash
# Test the alert expression manually in Prometheus
http://localhost:9090/graph?g0.expr=your_alert_expression
```

### Alert Fires Too Often

1. **Increase `for` duration**:
```yaml
for: 15m  # Require longer violation period
```

2. **Adjust threshold**:
```yaml
expr: metric > 0.95  # Instead of 0.90
```

3. **Add traffic filter**:
```yaml
expr: |
  metric > threshold
  and
  http:requests:rate5m > 0.1
```

### Notifications Not Received

1. **Check AlertManager logs**:
```bash
kubectl logs -n greenfield deployment/alertmanager
```

2. **Test receiver configuration**:
```bash
# Send test alert (see Testing section above)
```

3. **Verify routing**:
```bash
# Check AlertManager configuration
curl http://localhost:9093/api/v1/status
```

### Alert Storm

Too many alerts firing simultaneously:

1. **Check for root cause alert**:
- Is there a NodeNotReady causing many pod alerts?
- Is API server down causing scheduling alerts?

2. **Review inhibition rules**:
```yaml
# Add rule to suppress dependent alerts
```

3. **Group related alerts**:
```yaml
route:
  group_by: ['cluster', 'namespace']
  group_interval: 5m
```

## Further Reading

- [SLOs Guide](slos.md) - Understanding Service Level Objectives
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [AlertManager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
