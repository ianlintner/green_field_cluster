# OpenTelemetry Collector

OpenTelemetry Collector is a vendor-agnostic telemetry data pipeline used in the Greenfield Cluster for collecting, processing, and exporting observability data.

## Overview

The OpenTelemetry Collector provides:

- **Unified Telemetry**: Single pipeline for traces, metrics, and logs
- **Vendor Agnostic**: Works with any observability backend
- **Data Processing**: Filter, transform, and enrich telemetry
- **Multiple Exporters**: Send data to multiple backends
- **High Performance**: Efficient data collection and export

## Architecture

### Configuration

| Parameter | Default Value |
|-----------|---------------|
| **Version** | Latest |
| **OTLP gRPC Port** | 4317 |
| **OTLP HTTP Port** | 4318 |
| **Health Check Port** | 13133 |
| **CPU Request** | 200m |
| **Memory Request** | 512Mi |

### Pipeline

```
Application → OTel Collector → Backends
                    ↓
            [Jaeger, Prometheus, etc.]
```

## Usage

### Sending Telemetry

Applications send telemetry to the collector:

```
# Endpoint for applications
otel-collector.greenfield.svc.cluster.local:4317  # gRPC
otel-collector.greenfield.svc.cluster.local:4318  # HTTP
```

### Python Example

```python
from opentelemetry import trace, metrics
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider

# Configure exporters
trace_exporter = OTLPSpanExporter(
    endpoint="otel-collector.greenfield.svc.cluster.local:4317"
)
metric_exporter = OTLPMetricExporter(
    endpoint="otel-collector.greenfield.svc.cluster.local:4317"
)

# Set up providers
trace.set_tracer_provider(TracerProvider())
metrics.set_meter_provider(MeterProvider())
```

### Node.js Example

```javascript
const { NodeTracerProvider } = require('@opentelemetry/sdk-trace-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const provider = new NodeTracerProvider();
provider.addSpanProcessor(
  new BatchSpanProcessor(
    new OTLPTraceExporter({
      url: 'otel-collector.greenfield.svc.cluster.local:4317'
    })
  )
);
```

## Configuration

The collector is configured via ConfigMap:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  
  memory_limiter:
    check_interval: 1s
    limit_mib: 512

exporters:
  jaeger:
    endpoint: jaeger-collector:14250
    tls:
      insecure: true
  
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [jaeger]
    
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

## Monitoring

```bash
# Check collector status
kubectl get pods -n greenfield -l app=otel-collector

# View logs
kubectl logs -n greenfield deployment/otel-collector

# Check metrics
kubectl port-forward -n greenfield svc/otel-collector 8888:8888
curl http://localhost:8888/metrics
```

## Best Practices

1. **Resource Limits**: Set appropriate memory and CPU limits
2. **Batch Processing**: Use batch processor to reduce network calls
3. **Sampling**: Implement sampling for high-volume applications
4. **Multiple Exporters**: Send data to multiple backends
5. **Security**: Use TLS for production deployments

## Additional Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Jaeger Component](jaeger.md)
- [Prometheus Component](prometheus.md)
