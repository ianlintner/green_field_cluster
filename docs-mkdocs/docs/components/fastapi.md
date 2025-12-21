# FastAPI Example Application

The Greenfield Cluster includes a fully instrumented FastAPI application demonstrating best practices for cloud-native applications.

## Overview

The FastAPI example application showcases:

- **OpenTelemetry Integration**: Automatic distributed tracing
- **Prometheus Metrics**: Custom and automatic metrics
- **Database Connectivity**: Examples for Redis, PostgreSQL, MySQL, MongoDB
- **Kafka Integration**: Event publishing and consuming
- **Health Checks**: Kubernetes-ready health endpoints
- **Istio Integration**: Service mesh sidecar injection

## Architecture

### Features

| Feature | Implementation |
|---------|---------------|
| **Framework** | FastAPI (async Python) |
| **Tracing** | OpenTelemetry automatic instrumentation |
| **Metrics** | Prometheus client library |
| **Health Checks** | /health endpoint |
| **API Documentation** | Auto-generated OpenAPI/Swagger |

## Endpoints

### Health Check

```bash
GET /health
```

Returns application health status.

### Database Examples

```bash
# Redis
GET /redis
POST /redis

# PostgreSQL
GET /postgres
POST /postgres

# MySQL
GET /mysql

# MongoDB
GET /mongodb
POST /mongodb
```

### Kafka Example

```bash
POST /kafka
```

Publishes a message to Kafka.

### Metrics

```bash
GET /metrics
```

Prometheus metrics endpoint.

## Usage

### Accessing the Application

```bash
# Port forward
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/docs  # Swagger UI
```

### API Documentation

FastAPI provides automatic interactive API documentation:

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

## Implementation Examples

### Basic Endpoint with Tracing

```python
from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

@app.get("/")
async def root():
    # Automatically traced
    return {"message": "Hello World"}
```

### Database Connection

```python
import redis
from fastapi import FastAPI

app = FastAPI()

@app.get("/redis")
async def test_redis():
    r = redis.Redis(host='redis-master.greenfield.svc.cluster.local')
    r.set('key', 'value')
    value = r.get('key')
    return {"value": value.decode()}
```

### Custom Metrics

```python
from prometheus_client import Counter, Histogram
from fastapi import FastAPI

app = FastAPI()

REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests')
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

@app.get("/api/users")
async def get_users():
    REQUEST_COUNT.inc()
    with REQUEST_DURATION.time():
        # Your logic here
        return {"users": []}
```

## Building and Deploying

### Build Image

```bash
cd apps/fastapi-example

# Build image
docker build -t fastapi-example:latest .

# For Minikube
minikube image load fastapi-example:latest

# For cloud, push to registry
docker tag fastapi-example:latest your-registry/fastapi-example:latest
docker push your-registry/fastapi-example:latest
```

### Deploy

```bash
# Update image in manifests
# kustomize/base/fastapi-app/deployment.yaml

# Deploy
kubectl apply -k kustomize/base/
```

## Monitoring

### View Traces

1. Access Jaeger UI
2. Select "fastapi-app" service
3. View traces for requests

### View Metrics

1. Access Grafana
2. Explore metrics starting with `http_` or `fastapi_`
3. Create dashboards

### View Logs

```bash
# View application logs
kubectl logs -n greenfield deployment/fastapi-app

# Follow logs
kubectl logs -f -n greenfield deployment/fastapi-app
```

## Development

### Local Development

```bash
cd apps/fastapi-example

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install dependencies
pip install -r requirements.txt

# Run locally
uvicorn main:app --reload

# Access at http://localhost:8000
```

### Testing

```bash
# Run tests
pytest

# With coverage
pytest --cov=.
```

## Best Practices Demonstrated

1. **Async/Await**: Proper async implementation
2. **Dependency Injection**: FastAPI dependencies for shared resources
3. **Error Handling**: Proper exception handling and logging
4. **Connection Pooling**: Efficient database connections
5. **Configuration**: Environment-based configuration
6. **Observability**: Comprehensive tracing and metrics
7. **Health Checks**: Kubernetes-ready probes

## Customization

Use this as a template for your own applications:

1. Copy the application directory
2. Modify endpoints for your use case
3. Update database models
4. Add business logic
5. Update Kubernetes manifests

## Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [OpenTelemetry Component](otel.md)
- [Redis Component](redis.md)
- [Prometheus Component](prometheus.md)
