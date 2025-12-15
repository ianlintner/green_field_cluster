# FastAPI Example Application

This is an example FastAPI application with OpenTelemetry instrumentation, Prometheus metrics, and connections to all infrastructure components.

## Features

- **OpenTelemetry Tracing**: Automatic tracing with FastAPI instrumentation
- **Prometheus Metrics**: Request count and duration metrics
- **Database Connections**: Examples for Redis, PostgreSQL, MySQL, MongoDB
- **Kafka Integration**: Message producer example
- **Health Checks**: Health and readiness endpoints

## Endpoints

- `GET /` - Root endpoint with API information
- `GET /health` - Health check
- `GET /metrics` - Prometheus metrics
- `GET /redis` - Test Redis connection
- `GET /postgres` - Test PostgreSQL connection
- `GET /mysql` - Test MySQL connection
- `GET /mongodb` - Test MongoDB connection
- `POST /kafka` - Send test message to Kafka

## Environment Variables

- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint (default: http://otel-collector:4317)
- `REDIS_HOST` - Redis host (default: redis-master)
- `POSTGRES_HOST` - PostgreSQL host (default: postgres-lb)
- `MYSQL_HOST` - MySQL host (default: mysql-lb)
- `MONGODB_HOST` - MongoDB host (default: mongodb-lb)
- `KAFKA_BROKERS` - Kafka brokers (default: kafka-lb:9092)

## Building

```bash
docker build -t fastapi-example:latest .
```

## Running Locally

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Deploying to Kubernetes

See the Kubernetes manifests in the kustomize directory.
