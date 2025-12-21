# Backend Service

Example backend service demonstrating full observability stack with:

## Features

### Structured JSON Logging
- **ECS-compatible format**: Logs follow Elastic Common Schema
- **Trace correlation**: Automatic inclusion of `trace_id` and `span_id` in logs
- **Rich metadata**: Service, host, process information in every log entry
- **Machine-readable**: JSON format for easy parsing by log aggregation systems

### Distributed Tracing
- **OpenTelemetry integration**: Full OTLP instrumentation
- **Context propagation**: Trace context automatically propagated across services
- **Service-to-service calls**: Demonstrates distributed trace creation
- **Automatic instrumentation**: FastAPI and HTTP client instrumentation

### Prometheus Metrics
- **Request metrics**: Total requests and duration by endpoint
- **Upstream metrics**: Track service-to-service call performance
- **Distributed system metrics**: Metrics for understanding service dependencies

### Service-to-Service Communication
- **HTTP client**: Uses httpx with OpenTelemetry instrumentation
- **Context propagation**: W3C Trace Context automatically propagated
- **Error handling**: Proper error handling and logging for upstream failures

## Endpoints

### Core Endpoints
- `GET /` - Service information and available endpoints
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics

### Service-to-Service Endpoints
- `GET /call-frontend` - Call frontend service root endpoint
- `GET /call-frontend/{endpoint}` - Call specific frontend endpoint (e.g., `/call-frontend/redis`)
- `GET /distributed-trace` - Demonstrate complex distributed trace across multiple calls

## Log Format

Logs are structured JSON compatible with ECS (Elastic Common Schema):

```json
{
  "@timestamp": "2024-01-01T12:00:00.000Z",
  "log": {
    "level": "INFO",
    "logger": "app.main"
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

## Environment Variables

- `SERVICE_NAME` - Service name (default: `backend-service`)
- `SERVICE_VERSION` - Service version (default: `1.0.0`)
- `ENVIRONMENT` - Environment name (default: `development`)
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint (default: `http://otel-collector:4317`)
- `FRONTEND_SERVICE_URL` - Frontend service URL (default: `http://fastapi-app:8000`)

## Building

```bash
docker build -t backend-service:latest .
```

## Running Locally

```bash
# Set environment variables
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export FRONTEND_SERVICE_URL=http://localhost:8000

# Run the service
uvicorn app.main:app --host 0.0.0.0 --port 8001
```

## Observability Features

### Log-Trace Correlation

Every log entry includes `trace.id` and `trace.span_id` fields, allowing you to:
1. See logs for a specific trace in your log aggregation system
2. Jump from a trace in Jaeger to related logs
3. Correlate errors across logs and traces

### Distributed Tracing Example

Call the `/distributed-trace` endpoint and then view the trace in Jaeger:

```bash
# Make request
curl http://localhost:8001/distributed-trace

# View in Jaeger
# Port-forward: kubectl port-forward -n greenfield svc/jaeger-query 16686:16686
# Open: http://localhost:16686
# Search for: backend-service
# You'll see a trace spanning multiple services
```

### Structured Log Querying

With structured logs, you can easily query for specific scenarios:

```
# Find all requests to a specific endpoint
{service.name="backend-service" AND http.request.path="/call-frontend"}

# Find slow requests
{service.name="backend-service" AND http.response.duration_ms > 1000}

# Find errors
{service.name="backend-service" AND log.level="ERROR"}

# Find logs for a specific trace
{trace.id="1234567890abcdef1234567890abcdef"}
```

## Integration with Log Aggregation

This service's log format is compatible with:

- **Splunk**: Use HTTP Event Collector (HEC) with JSON format
- **Elasticsearch/ELK**: Directly compatible with ECS
- **GCP Cloud Logging**: Use structured logs with trace correlation
- **AWS CloudWatch**: Use JSON log format
- **Grafana Loki**: Use LogQL to query structured fields

See the [Logging Integrations documentation](../../docs-mkdocs/docs/observability/logging-integrations.md) for detailed setup instructions.
