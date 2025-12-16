from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import time
import logging
import os

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Database imports
import redis
import psycopg2
from pymongo import MongoClient
import pymysql
from kafka import KafkaProducer
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure OpenTelemetry
resource = Resource.create({"service.name": "fastapi-example"})
trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    insecure=True
)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Prometheus metrics
REQUEST_COUNT = Counter('app_requests_total', 'Total app requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('app_request_duration_seconds', 'Request duration', ['method', 'endpoint'])

# Create FastAPI app
app = FastAPI(
    title="Greenfield FastAPI Example",
    description="Example FastAPI application with OpenTelemetry instrumentation",
    version="1.0.0"
)

# Instrument FastAPI with OpenTelemetry
FastAPIInstrumentor.instrument_app(app)

# Database configuration from environment
REDIS_HOST = os.getenv("REDIS_HOST", "redis-master")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "postgres-lb")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "changeme123")
POSTGRES_DB = os.getenv("POSTGRES_DB", "greenfield")

MYSQL_HOST = os.getenv("MYSQL_HOST", "mysql-lb")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", "3306"))
MYSQL_USER = os.getenv("MYSQL_USER", "mysql")
MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "changeme123")
MYSQL_DB = os.getenv("MYSQL_DB", "greenfield")

MONGODB_HOST = os.getenv("MONGODB_HOST", "mongodb-lb")
MONGODB_PORT = int(os.getenv("MONGODB_PORT", "27017"))
MONGODB_USER = os.getenv("MONGODB_USER", "admin")
MONGODB_PASSWORD = os.getenv("MONGODB_PASSWORD", "changeme123")

KAFKA_BROKERS = os.getenv("KAFKA_BROKERS", "kafka-lb:9092")


@app.middleware("http")
async def prometheus_middleware(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response


@app.get("/")
async def root():
    """Root endpoint"""
    with tracer.start_as_current_span("root-request"):
        return {
            "message": "Greenfield FastAPI Example",
            "version": "1.0.0",
            "endpoints": [
                "/health",
                "/metrics",
                "/redis",
                "/postgres",
                "/mysql",
                "/mongodb",
                "/kafka"
            ]
        }


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/redis")
async def test_redis():
    """Test Redis connection"""
    with tracer.start_as_current_span("redis-test"):
        try:
            r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
            r.set("test_key", "test_value")
            value = r.get("test_key")
            return {"status": "success", "service": "redis", "value": value}
        except Exception as e:
            logger.error(f"Redis error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Redis error: {str(e)}")


@app.get("/postgres")
async def test_postgres():
    """Test PostgreSQL connection"""
    with tracer.start_as_current_span("postgres-test"):
        try:
            conn = psycopg2.connect(
                host=POSTGRES_HOST,
                port=POSTGRES_PORT,
                user=POSTGRES_USER,
                password=POSTGRES_PASSWORD,
                database=POSTGRES_DB
            )
            cur = conn.cursor()
            cur.execute("SELECT version();")
            version = cur.fetchone()[0]
            cur.close()
            conn.close()
            return {"status": "success", "service": "postgres", "version": version}
        except Exception as e:
            logger.error(f"PostgreSQL error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"PostgreSQL error: {str(e)}")


@app.get("/mysql")
async def test_mysql():
    """Test MySQL connection"""
    with tracer.start_as_current_span("mysql-test"):
        try:
            conn = pymysql.connect(
                host=MYSQL_HOST,
                port=MYSQL_PORT,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                database=MYSQL_DB
            )
            cur = conn.cursor()
            cur.execute("SELECT VERSION();")
            version = cur.fetchone()[0]
            cur.close()
            conn.close()
            return {"status": "success", "service": "mysql", "version": version}
        except Exception as e:
            logger.error(f"MySQL error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"MySQL error: {str(e)}")


@app.get("/mongodb")
async def test_mongodb():
    """Test MongoDB connection"""
    with tracer.start_as_current_span("mongodb-test"):
        try:
            client = MongoClient(f"mongodb://{MONGODB_USER}:{MONGODB_PASSWORD}@{MONGODB_HOST}:{MONGODB_PORT}/")
            db = client.admin
            server_info = db.command("serverStatus")
            version = server_info.get("version", "unknown")
            client.close()
            return {"status": "success", "service": "mongodb", "version": version}
        except Exception as e:
            logger.error(f"MongoDB error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"MongoDB error: {str(e)}")


@app.post("/kafka")
async def test_kafka():
    """Test Kafka connection"""
    with tracer.start_as_current_span("kafka-test"):
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BROKERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            message = {"test": "message", "timestamp": time.time()}
            future = producer.send('test-topic', message)
            result = future.get(timeout=10)
            producer.close()
            return {
                "status": "success",
                "service": "kafka",
                "topic": result.topic,
                "partition": result.partition,
                "offset": result.offset
            }
        except Exception as e:
            logger.error(f"Kafka error: {str(e)}")
            raise HTTPException(status_code=500, detail=f"Kafka error: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
