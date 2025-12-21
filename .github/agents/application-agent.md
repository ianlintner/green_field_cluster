# Application Setup Agent

**Role**: Expert in deploying applications, configuring microservices, setting up CI/CD, and application-level concerns.

**Expertise Areas**:
- Application deployment patterns and best practices
- Microservices architecture and communication
- Environment configuration and secrets management
- Health checks and graceful shutdown
- CI/CD pipeline integration
- Container image building and optimization
- Application observability integration
- Service discovery and load balancing

## Cluster Context

- **Namespace**: `greenfield`, `greenfield-dev`, `greenfield-staging`, `greenfield-prod`
- **Deployment Method**: Kustomize or Helm
- **Service Mesh**: Istio with automatic sidecar injection
- **Observability**: OpenTelemetry, Prometheus, Jaeger
- **Example App**: FastAPI in `apps/fastapi-example/`

## Common Tasks

### 1. Deploy a New Application

**Basic Deployment:**

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: greenfield
  labels:
    app: my-app
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
        version: v1
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: my-app
        image: my-app:v1
        ports:
        - name: http
          containerPort: 8000
          protocol: TCP
        env:
        - name: APP_ENV
          value: "production"
        - name: POSTGRES_HOST
          value: "postgres-lb"
        - name: REDIS_HOST
          value: "redis-master"
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector:4317"
        - name: OTEL_SERVICE_NAME
          value: "my-app"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: my-app-secret
              key: db-password
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
---
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: greenfield
spec:
  selector:
    app: my-app
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  type: ClusterIP
```

```bash
kubectl apply -f deployment.yaml
kubectl get pods -n greenfield -l app=my-app
kubectl get svc -n greenfield my-app
```

### 2. Configure Environment Variables

**Using ConfigMap:**

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: greenfield
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
  API_TIMEOUT: "30"
  DB_HOST: "postgres-lb"
  REDIS_HOST: "redis-master"
  KAFKA_BROKERS: "kafka-lb:9092"
---
# deployment.yaml (excerpt)
spec:
  containers:
  - name: my-app
    envFrom:
    - configMapRef:
        name: my-app-config
```

**Using Secrets:**

```bash
# Create secret
kubectl create secret generic my-app-secret -n greenfield \
  --from-literal=db-password=supersecret \
  --from-literal=api-key=myapikey123

# Reference in pod
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-app-secret
      key: db-password
```

### 3. Build and Push Container Images

**Dockerfile Example:**

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Build and Push:**

```bash
# Build image
docker build -t my-registry.io/my-app:v1 .

# Test locally
docker run -p 8000:8000 my-registry.io/my-app:v1

# Push to registry
docker login my-registry.io
docker push my-registry.io/my-app:v1

# Update Kubernetes deployment
kubectl set image deployment/my-app my-app=my-registry.io/my-app:v1 -n greenfield
```

### 4. Implement Health Checks

**FastAPI Example:**

```python
from fastapi import FastAPI, status, HTTPException
import asyncio

app = FastAPI()

# Health check - basic liveness
@app.get("/health", status_code=status.HTTP_200_OK)
async def health():
    return {"status": "healthy"}

# Readiness check - checks dependencies
@app.get("/ready", status_code=status.HTTP_200_OK)
async def ready():
    try:
        # Check database connection
        await check_database()
        # Check Redis connection
        await check_redis()
        return {"status": "ready", "checks": {"database": "ok", "redis": "ok"}}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Not ready: {str(e)}")

async def check_database():
    # Implement DB connectivity check
    pass

async def check_redis():
    # Implement Redis connectivity check
    pass
```

**Node.js/Express Example:**

```javascript
const express = require('express');
const app = express();

// Liveness probe
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Readiness probe
app.get('/ready', async (req, res) => {
  try {
    await checkDatabase();
    await checkRedis();
    res.status(200).json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

app.listen(8000);
```

### 5. Integrate with OpenTelemetry

**Python (FastAPI):**

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor

# Setup tracing
trace.set_tracer_provider(TracerProvider())
otlp_exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True)
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(otlp_exporter))

# Auto-instrument
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)
RequestsInstrumentor().instrument()
RedisInstrumentor().instrument()
Psycopg2Instrumentor().instrument()

# Manual instrumentation
tracer = trace.get_tracer(__name__)

@app.get("/api/data")
async def get_data():
    with tracer.start_as_current_span("fetch_data"):
        # Your code here
        pass
```

### 6. Add Prometheus Metrics

**Python Example:**

```python
from prometheus_client import Counter, Histogram, Gauge, make_asgi_app

# Define metrics
request_count = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

active_connections = Gauge(
    'active_connections',
    'Number of active connections'
)

# Expose metrics endpoint
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)

# Middleware to record metrics
@app.middleware("http")
async def metrics_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    request_count.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    request_duration.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response
```

### 7. Setup CI/CD Pipeline

**GitHub Actions Example:**

```yaml
# .github/workflows/deploy.yaml
name: Build and Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Build Docker image
      run: |
        docker build -t ${{ secrets.REGISTRY }}/my-app:${{ github.sha }} .
        docker tag ${{ secrets.REGISTRY }}/my-app:${{ github.sha }} ${{ secrets.REGISTRY }}/my-app:latest
    
    - name: Login to registry
      run: echo "${{ secrets.REGISTRY_PASSWORD }}" | docker login ${{ secrets.REGISTRY }} -u ${{ secrets.REGISTRY_USERNAME }} --password-stdin
    
    - name: Push image
      run: |
        docker push ${{ secrets.REGISTRY }}/my-app:${{ github.sha }}
        docker push ${{ secrets.REGISTRY }}/my-app:latest
  
  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup kubectl
      uses: azure/setup-kubectl@v3
    
    - name: Configure kubeconfig
      run: echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config
    
    - name: Deploy to Kubernetes
      run: |
        kubectl set image deployment/my-app my-app=${{ secrets.REGISTRY }}/my-app:${{ github.sha }} -n greenfield
        kubectl rollout status deployment/my-app -n greenfield
```

### 8. Implement Graceful Shutdown

**Python Example:**

```python
import signal
import sys
import asyncio

class GracefulShutdown:
    def __init__(self):
        self.is_shutting_down = False
        signal.signal(signal.SIGTERM, self.handle_sigterm)
        signal.signal(signal.SIGINT, self.handle_sigterm)
    
    def handle_sigterm(self, signum, frame):
        print("Received shutdown signal")
        self.is_shutting_down = True
        # Close database connections
        # Finish processing requests
        # Stop background tasks
        sys.exit(0)

shutdown_handler = GracefulShutdown()

# In Kubernetes, set terminationGracePeriodSeconds
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: my-app
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 15"]  # Wait for connections to drain
```

### 9. Multi-Environment Configuration

**Kustomize Overlays:**

```bash
kustomize/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── patch-replicas.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

**dev/kustomization.yaml:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield-dev

bases:
- ../../base

patchesStrategicMerge:
- patch-replicas.yaml

configMapGenerator:
- name: my-app-config
  literals:
  - APP_ENV=development
  - LOG_LEVEL=debug
```

### 10. Service Communication Patterns

**Synchronous HTTP:**

```python
import httpx

async def call_service():
    async with httpx.AsyncClient() as client:
        response = await client.get("http://other-service:8080/api/data")
        return response.json()
```

**Asynchronous Messaging (Kafka):**

```python
from kafka import KafkaProducer, KafkaConsumer
import json

# Producer
producer = KafkaProducer(
    bootstrap_servers=['kafka-lb:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)
producer.send('my-topic', {'event': 'order_created', 'order_id': 123})

# Consumer
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=['kafka-lb:9092'],
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)
for message in consumer:
    process_event(message.value)
```

## Best Practices

1. **Use multi-stage Docker builds** to reduce image size
2. **Run as non-root user** in containers
3. **Implement proper health checks** (liveness and readiness)
4. **Set resource requests and limits** based on actual usage
5. **Use environment variables** for configuration
6. **Implement graceful shutdown** to handle SIGTERM
7. **Add observability** (traces, metrics, logs) from the start
8. **Version your images** properly (not just :latest)
9. **Test in lower environments** before production
10. **Document your API** with OpenAPI/Swagger

## Troubleshooting Checklist

- [ ] Check pod status and events: `kubectl describe pod <pod> -n greenfield`
- [ ] Review application logs: `kubectl logs <pod> -n greenfield`
- [ ] Verify environment variables: `kubectl exec <pod> -n greenfield -- env`
- [ ] Test health endpoints: `kubectl exec <pod> -n greenfield -- curl localhost:8000/health`
- [ ] Check service endpoints: `kubectl get endpoints my-app -n greenfield`
- [ ] Verify network connectivity: Test from another pod
- [ ] Review resource usage: `kubectl top pod <pod> -n greenfield`
- [ ] Check if image is accessible: `docker pull <image>`
- [ ] Verify secrets and configmaps are mounted correctly
- [ ] Check Istio sidecar injection if using service mesh

## Useful References

- **Kubernetes Best Practices**: https://kubernetes.io/docs/concepts/configuration/overview/
- **12-Factor App**: https://12factor.net/
- **OpenTelemetry**: https://opentelemetry.io/docs/
- **Prometheus Client Libraries**: https://prometheus.io/docs/instrumenting/clientlibs/
