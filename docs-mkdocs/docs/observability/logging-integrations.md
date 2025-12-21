# Logging Integrations

This guide covers integrating the Greenfield Cluster's structured logging with popular log aggregation platforms.

## Table of Contents

1. [Overview](#overview)
2. [Log Format](#log-format)
3. [Splunk Integration](#splunk-integration)
4. [Elasticsearch/ELK Stack](#elasticsearchelk-stack)
5. [GCP Cloud Logging](#gcp-cloud-logging)
6. [AWS CloudWatch](#aws-cloudwatch)
7. [Grafana Loki](#grafana-loki)
8. [Datadog](#datadog)
9. [New Relic](#new-relic)
10. [Common Patterns](#common-patterns)

## Overview

The backend-service and updated fastapi-example use structured JSON logging that's compatible with most log aggregation platforms. Logs include:

- **ECS-compatible format**: Works with Elastic Common Schema
- **Trace correlation**: `trace.id` and `trace.span_id` for log-trace correlation
- **Structured fields**: Machine-readable JSON for easy querying
- **Rich metadata**: Service, host, process information

## Log Format

Example log entry:

```json
{
  "@timestamp": "2024-01-15T10:30:45.123Z",
  "timestamp": "2024-01-15T10:30:45.123Z",
  "log": {
    "level": "INFO",
    "logger": "app.main",
    "origin": {
      "file": {
        "name": "main.py",
        "line": 145
      },
      "function": "call_frontend"
    }
  },
  "message": "GET /call-frontend - 200 (45.23ms)",
  "service": {
    "name": "backend-service",
    "version": "1.0.0",
    "environment": "production"
  },
  "trace": {
    "id": "1234567890abcdef1234567890abcdef",
    "span_id": "1234567890abcdef"
  },
  "process": {
    "pid": 1234
  },
  "host": {
    "hostname": "backend-service-7d8f9c-xkz2p"
  },
  "http": {
    "request": {
      "method": "GET",
      "path": "/call-frontend"
    },
    "response": {
      "status_code": 200,
      "duration_ms": 45.23
    }
  }
}
```

## Splunk Integration

### Using HTTP Event Collector (HEC)

**Step 1: Create HEC Token in Splunk**

1. Navigate to Settings → Data Inputs → HTTP Event Collector
2. Click "New Token"
3. Name your token (e.g., "kubernetes-logs")
4. Select source type: `_json`
5. Copy the token value

**Step 2: Deploy Fluent Bit as DaemonSet**

Create `kustomize/base/logging/fluentbit-splunk.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: greenfield
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        off
        Log_Level     info
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Path              /var/log/containers/*greenfield*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off
        K8S-Logging.Parser  On
        K8S-Logging.Exclude On

    [OUTPUT]
        Name            splunk
        Match           *
        Host            YOUR_SPLUNK_HOST
        Port            8088
        Splunk_Token    YOUR_HEC_TOKEN
        TLS             On
        TLS.Verify      Off

  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.1
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
```

**Step 3: Query Logs in Splunk**

```spl
# Find all backend-service logs
index=kubernetes service.name="backend-service"

# Find errors
index=kubernetes service.name="backend-service" log.level="ERROR"

# Find slow requests
index=kubernetes service.name="backend-service" http.response.duration_ms>1000

# Find logs for specific trace
index=kubernetes trace.id="1234567890abcdef1234567890abcdef"

# Correlation: errors over time
index=kubernetes service.name="backend-service" log.level="ERROR" 
| timechart count by service.name
```

## Elasticsearch/ELK Stack

### Using Filebeat

**Step 1: Deploy Elasticsearch and Kibana**

```bash
# Add Elastic Helm repo
helm repo add elastic https://helm.elastic.co

# Install Elasticsearch
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --create-namespace

# Install Kibana
helm install kibana elastic/kibana \
  --namespace logging
```

**Step 2: Deploy Filebeat**

Create `kustomize/base/logging/filebeat.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: greenfield
data:
  filebeat.yml: |
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*greenfield*.log
      json.keys_under_root: true
      json.add_error_key: true
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

    output.elasticsearch:
      hosts: ['${ELASTICSEARCH_HOST:elasticsearch}:${ELASTICSEARCH_PORT:9200}']
      index: "kubernetes-logs-%{+yyyy.MM.dd}"

    setup.ilm.enabled: false
    setup.template.name: "kubernetes-logs"
    setup.template.pattern: "kubernetes-logs-*"
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      serviceAccountName: filebeat
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.11.0
        env:
        - name: ELASTICSEARCH_HOST
          value: elasticsearch.logging.svc.cluster.local
        - name: ELASTICSEARCH_PORT
          value: "9200"
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: config
          mountPath: /usr/share/filebeat/filebeat.yml
          subPath: filebeat.yml
        - name: data
          mountPath: /usr/share/filebeat/data
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: varlog
        hostPath:
          path: /var/log
      - name: data
        emptyDir: {}
```

**Step 3: Create Kibana Index Pattern**

1. Open Kibana
2. Navigate to Management → Index Patterns
3. Create pattern: `kubernetes-logs-*`
4. Select timestamp field: `@timestamp`

**Step 4: Query Logs**

```
# KQL (Kibana Query Language) examples

# Find backend service logs
service.name:"backend-service"

# Find errors
service.name:"backend-service" AND log.level:"ERROR"

# Find slow requests
service.name:"backend-service" AND http.response.duration_ms > 1000

# Find logs for trace
trace.id:"1234567890abcdef1234567890abcdef"

# Visualize error rate
service.name:"backend-service" AND log.level:"ERROR"
# Then create visualization: Count over time
```

## GCP Cloud Logging

### Using Fluent Bit with Google Cloud Output

**Step 1: Create Service Account**

```bash
# Create service account
gcloud iam service-accounts create logging-writer \
  --display-name="Logging Writer"

# Grant permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:logging-writer@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"

# Create key
gcloud iam service-accounts keys create logging-key.json \
  --iam-account=logging-writer@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Create secret
kubectl create secret generic gcp-logging-key \
  --from-file=key.json=logging-key.json \
  --namespace=greenfield
```

**Step 2: Deploy Fluent Bit**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-gcp-config
  namespace: greenfield
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        off
        Log_Level     info

    [INPUT]
        Name              tail
        Path              /var/log/containers/*greenfield*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Merge_Log           On

    [OUTPUT]
        Name          stackdriver
        Match         *
        google_service_credentials /var/secrets/google/key.json
        resource      k8s_container
        k8s_cluster_name    YOUR_CLUSTER_NAME
        k8s_cluster_location YOUR_CLUSTER_LOCATION

  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit-gcp
  namespace: greenfield
spec:
  selector:
    matchLabels:
      app: fluent-bit-gcp
  template:
    metadata:
      labels:
        app: fluent-bit-gcp
    spec:
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.1
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
        - name: google-cloud-key
          mountPath: /var/secrets/google
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-gcp-config
      - name: google-cloud-key
        secret:
          secretName: gcp-logging-key
```

**Step 3: Query in Cloud Logging**

```
# Find backend service logs
resource.type="k8s_container"
labels."k8s-pod/app"="backend-service"

# Find errors
resource.type="k8s_container"
labels."k8s-pod/app"="backend-service"
jsonPayload.log.level="ERROR"

# Find slow requests
resource.type="k8s_container"
labels."k8s-pod/app"="backend-service"
jsonPayload.http.response.duration_ms > 1000

# Find logs for trace
resource.type="k8s_container"
jsonPayload.trace.id="1234567890abcdef1234567890abcdef"
```

## AWS CloudWatch

### Using Fluent Bit with CloudWatch Output

**Step 1: Create IAM Policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Step 2: Deploy Fluent Bit**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-cloudwatch-config
  namespace: greenfield
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        off
        Log_Level     info

    [INPUT]
        Name              tail
        Path              /var/log/containers/*greenfield*.log
        Parser            docker
        Tag               kube.*

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Merge_Log           On

    [OUTPUT]
        Name                cloudwatch_logs
        Match               *
        region              us-east-1
        log_group_name      /kubernetes/greenfield
        log_stream_prefix   from-fluent-bit-
        auto_create_group   true

  parsers.conf: |
    [PARSER]
        Name        docker
        Format      json
        Time_Key    time
        Time_Format %Y-%m-%dT%H:%M:%S.%L%z
```

**Step 3: Query CloudWatch Logs Insights**

```
# Find backend service logs
fields @timestamp, message, service.name
| filter service.name = "backend-service"
| sort @timestamp desc

# Find errors
fields @timestamp, message, log.level, error
| filter service.name = "backend-service" and log.level = "ERROR"
| sort @timestamp desc

# Find slow requests
fields @timestamp, http.request.path, http.response.duration_ms
| filter service.name = "backend-service" and http.response.duration_ms > 1000
| sort http.response.duration_ms desc

# Aggregate errors by endpoint
fields http.request.path
| filter service.name = "backend-service" and log.level = "ERROR"
| stats count() by http.request.path
```

## Grafana Loki

### Using Promtail

**Step 1: Install Loki and Grafana**

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Install Loki
helm install loki grafana/loki-stack \
  --namespace logging \
  --create-namespace \
  --set grafana.enabled=true \
  --set prometheus.enabled=false
```

**Step 2: Deploy Promtail**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: greenfield
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki.logging.svc.cluster.local:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            regex: (backend-service|fastapi-app)
            action: keep
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node_name
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
        pipeline_stages:
          - json:
              expressions:
                level: log.level
                service: service.name
                trace_id: trace.id
                span_id: trace.span_id
          - labels:
              level:
              service:
              trace_id:
```

**Step 3: Query with LogQL**

```logql
# Find backend service logs
{app="backend-service"}

# Find errors
{app="backend-service"} | json | level="ERROR"

# Find slow requests
{app="backend-service"} | json | http_response_duration_ms > 1000

# Find logs for trace
{trace_id="1234567890abcdef1234567890abcdef"}

# Rate of errors
rate({app="backend-service"} | json | level="ERROR" [5m])

# P95 latency
quantile_over_time(0.95, 
  {app="backend-service"} 
  | json 
  | unwrap http_response_duration_ms [5m]
) by (service)
```

## Datadog

### Using Datadog Agent

**Step 1: Create API Key Secret**

```bash
kubectl create secret generic datadog-secret \
  --from-literal api-key=YOUR_DATADOG_API_KEY \
  --namespace=greenfield
```

**Step 2: Deploy Datadog Agent**

```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog datadog/datadog \
  --namespace greenfield \
  --set datadog.apiKeyExistingSecret=datadog-secret \
  --set datadog.logs.enabled=true \
  --set datadog.logs.containerCollectAll=true \
  --set datadog.apm.enabled=true
```

**Step 3: Query in Datadog**

```
# Find backend service logs
service:backend-service

# Find errors
service:backend-service status:error

# Find slow requests
service:backend-service @http.response.duration_ms:>1000

# Find logs for trace
@trace_id:1234567890abcdef1234567890abcdef
```

## New Relic

### Using New Relic Kubernetes Integration

**Step 1: Install New Relic**

```bash
helm repo add newrelic https://helm-charts.newrelic.com
helm install newrelic-bundle newrelic/nri-bundle \
  --set global.licenseKey=YOUR_LICENSE_KEY \
  --set global.cluster=greenfield-cluster \
  --namespace=greenfield \
  --set newrelic-infrastructure.privileged=true \
  --set ksm.enabled=true \
  --set prometheus.enabled=true \
  --set kubeEvents.enabled=true \
  --set logging.enabled=true
```

**Step 2: Query NRQL**

```sql
-- Find backend service logs
SELECT * FROM Log WHERE service.name = 'backend-service'

-- Find errors
SELECT * FROM Log WHERE service.name = 'backend-service' AND log.level = 'ERROR'

-- Find slow requests
SELECT * FROM Log 
WHERE service.name = 'backend-service' 
AND http.response.duration_ms > 1000

-- Error rate over time
SELECT count(*) FROM Log 
WHERE service.name = 'backend-service' AND log.level = 'ERROR'
TIMESERIES
```

## Common Patterns

### Log-Trace Correlation

In any system, you can correlate logs with traces:

1. **From Trace to Logs**: Click trace in Jaeger, copy `trace_id`, search logs
2. **From Logs to Trace**: See `trace_id` in log, search Jaeger

Example workflow:
```
1. User reports slow request
2. Find error in logs: trace_id = "abc123..."
3. Search Jaeger for trace_id = "abc123..."
4. See full distributed trace
5. Identify slow service
6. Search logs for that service with same trace_id
7. Find root cause in logs
```

### Alerting on Logs

Most platforms support alerting on log patterns:

**Splunk Alert:**
```spl
index=kubernetes service.name="backend-service" log.level="ERROR"
| stats count by service.name
| where count > 10
```

**Elasticsearch Watcher:**
```json
{
  "trigger": {
    "schedule": { "interval": "5m" }
  },
  "input": {
    "search": {
      "request": {
        "indices": ["kubernetes-logs-*"],
        "body": {
          "query": {
            "bool": {
              "must": [
                { "term": { "service.name": "backend-service" }},
                { "term": { "log.level": "ERROR" }}
              ]
            }
          }
        }
      }
    }
  },
  "condition": {
    "compare": {
      "ctx.payload.hits.total": { "gt": 10 }
    }
  }
}
```

### Log Sampling

For high-volume services, sample logs:

```python
import random

def should_log_debug():
    # Log 1% of debug messages
    return random.random() < 0.01

if should_log_debug() or log_level >= logging.INFO:
    logger.log(level, message)
```

### Log Retention

Set appropriate retention periods:

- **Development**: 7 days
- **Staging**: 30 days
- **Production**: 90+ days
- **Compliance**: As required (years)

### Cost Optimization

1. **Filter at source**: Don't send debug logs from production
2. **Sample high-volume**: Sample verbose logs
3. **Use index patterns**: Separate hot/warm/cold storage
4. **Archive old logs**: Move to cheaper storage (S3, GCS)

## Further Reading

- [Observability Overview](overview.md)
- [Backend Service README](../../apps/backend-service/README.md)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [ECS Field Reference](https://www.elastic.co/guide/en/ecs/current/ecs-field-reference.html)
