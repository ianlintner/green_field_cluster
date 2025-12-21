# Jaeger

Jaeger is an open-source, end-to-end distributed tracing system used in the Greenfield Cluster for monitoring and troubleshooting microservices.

## Overview

Jaeger in the Greenfield Cluster provides:

- **Distributed Tracing**: Track requests across microservices
- **Performance Monitoring**: Identify bottlenecks and latency issues
- **Root Cause Analysis**: Quickly diagnose issues in distributed systems
- **Service Dependencies**: Visualize service interactions
- **OpenTelemetry Integration**: Receives traces via OpenTelemetry Collector

## Architecture

### Components

| Component | Purpose | Port |
|-----------|---------|------|
| **Jaeger Query** | UI and API for trace queries | 16686 |
| **Jaeger Collector** | Receives trace data | 14250 |
| **Jaeger Agent** | Local agent for trace forwarding | 6831/6832 |

### Configuration

| Parameter | Default Value |
|-----------|---------------|
| **Memory Backend** | In-memory (development) |
| **Trace Retention** | 24 hours |
| **CPU Request** | 100m |
| **Memory Request** | 256Mi |

## Usage

### Accessing Jaeger UI

```bash
# Port forward to Jaeger UI
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686

# Open in browser
http://localhost:16686
```

### Instrumenting Applications

Applications send traces to OpenTelemetry Collector, which forwards to Jaeger:

#### Python

```python
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure tracer
provider = TracerProvider()
processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint="otel-collector.greenfield.svc.cluster.local:4317")
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Create traces
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("operation"):
    # Your code here
    pass
```

#### Node.js

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
provider.register();
```

## Features

### Trace Search

- Search by service name
- Search by operation name
- Filter by tags
- Filter by duration
- Filter by time range

### Service Dependencies

View service dependency graph showing:
- Service relationships
- Request volumes
- Error rates
- Latencies

### Trace Analysis

Each trace shows:
- Request flow across services
- Timing information per span
- Tags and logs
- Errors and exceptions

## Best Practices

1. **Meaningful Span Names**: Use descriptive operation names
2. **Add Context**: Include relevant tags (user_id, request_id, etc.)
3. **Sample Appropriately**: Sample high-volume endpoints to reduce overhead
4. **Error Logging**: Log errors with trace context
5. **Performance Impact**: Monitor tracing overhead (<5% recommended)

## Troubleshooting

### No Traces Appearing

```bash
# Check Jaeger pods
kubectl get pods -n greenfield -l app=jaeger

# Check OTel Collector
kubectl logs -n greenfield deployment/otel-collector

# Verify application is sending traces
# Check application logs for OTel errors
```

### High Memory Usage

```bash
# Reduce trace retention or switch to persistent storage
# Configure sampling to reduce trace volume
```

## Production Setup

For production, use persistent storage:

- **Elasticsearch**: Recommended for large-scale deployments
- **Cassandra**: Alternative persistent backend
- **Kafka**: Buffer for high-throughput scenarios

## Additional Resources

- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Component](otel.md)
- [Grafana Component](grafana.md)
