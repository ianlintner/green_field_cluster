"""
Backend Service - Example service with full observability
Demonstrates:
- Structured JSON logging with trace correlation
- Service-to-service calls with context propagation
- OpenTelemetry distributed tracing
- Prometheus metrics for distributed systems
- Common logging formats (ECS-compatible)
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import os
import json
import logging
from datetime import datetime
import httpx
from typing import Optional

from opentelemetry import trace, context
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator
from opentelemetry.propagate import set_global_textmap, get_global_textmap

# Custom JSON formatter for structured logging with trace correlation
class StructuredJSONFormatter(logging.Formatter):
    """
    Structured JSON log formatter compatible with ECS (Elastic Common Schema)
    Includes trace context for log-trace correlation
    """
    
    def format(self, record):
        # Get current trace context
        current_span = trace.get_current_span()
        trace_id = None
        span_id = None
        
        if current_span and current_span.get_span_context().is_valid:
            ctx = current_span.get_span_context()
            trace_id = format(ctx.trace_id, '032x')
            span_id = format(ctx.span_id, '016x')
        
        # Build structured log entry
        log_data = {
            # Timestamp
            "@timestamp": datetime.utcnow().isoformat() + "Z",
            "timestamp": datetime.utcfromtimestamp(record.created).isoformat() + "Z",
            
            # Log metadata
            "log": {
                "level": record.levelname,
                "logger": record.name,
                "origin": {
                    "file": {
                        "name": record.filename,
                        "line": record.lineno
                    },
                    "function": record.funcName
                }
            },
            
            # Message
            "message": record.getMessage(),
            
            # Service metadata
            "service": {
                "name": os.getenv("SERVICE_NAME", "backend-service"),
                "version": os.getenv("SERVICE_VERSION", "1.0.0"),
                "environment": os.getenv("ENVIRONMENT", "development")
            },
            
            # Trace context (for log-trace correlation)
            "trace": {
                "id": trace_id,
                "span_id": span_id
            } if trace_id else {},
            
            # Process metadata
            "process": {
                "pid": os.getpid()
            },
            
            # Host metadata
            "host": {
                "hostname": os.getenv("HOSTNAME", "localhost")
            }
        }
        
        # Add exception info if present
        if record.exc_info:
            log_data["error"] = {
                "type": record.exc_info[0].__name__ if record.exc_info[0] else None,
                "message": str(record.exc_info[1]) if record.exc_info[1] else None,
                "stack_trace": self.formatException(record.exc_info)
            }
        
        # Add custom fields from extra
        if hasattr(record, 'extra_fields'):
            log_data.update(record.extra_fields)
        
        return json.dumps(log_data)


# Configure structured logging
def setup_logging():
    """Configure structured JSON logging"""
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Remove default handlers
    logger.handlers = []
    
    # Add JSON handler
    handler = logging.StreamHandler()
    handler.setFormatter(StructuredJSONFormatter())
    logger.addHandler(handler)
    
    return logging.getLogger(__name__)


logger = setup_logging()

# Configure OpenTelemetry
resource = Resource.create({
    "service.name": os.getenv("SERVICE_NAME", "backend-service"),
    "service.version": os.getenv("SERVICE_VERSION", "1.0.0"),
    "deployment.environment": os.getenv("ENVIRONMENT", "development")
})

trace.set_tracer_provider(TracerProvider(resource=resource))
tracer = trace.get_tracer(__name__)

# Configure OTLP exporter
otlp_exporter = OTLPSpanExporter(
    endpoint=os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    insecure=True
)
span_processor = BatchSpanProcessor(otlp_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Set global propagator for context propagation
set_global_textmap(TraceContextTextMapPropagator())

# Prometheus metrics for distributed systems
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status', 'service']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint', 'service']
)

UPSTREAM_REQUEST_COUNT = Counter(
    'upstream_requests_total',
    'Total upstream service requests',
    ['upstream_service', 'method', 'status']
)

UPSTREAM_REQUEST_DURATION = Histogram(
    'upstream_request_duration_seconds',
    'Upstream service request duration',
    ['upstream_service', 'method']
)

# Create FastAPI app
app = FastAPI(
    title="Backend Service",
    description="Example backend service with full observability stack",
    version="1.0.0"
)

# Instrument FastAPI and HTTPX with OpenTelemetry
FastAPIInstrumentor.instrument_app(app)
HTTPXClientInstrumentor().instrument()

# Configuration
FRONTEND_SERVICE_URL = os.getenv("FRONTEND_SERVICE_URL", "http://fastapi-app:8000")


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    """Log all requests with trace context"""
    start_time = time.time()
    
    # Get trace context
    current_span = trace.get_current_span()
    trace_id = None
    span_id = None
    
    if current_span and current_span.get_span_context().is_valid:
        ctx = current_span.get_span_context()
        trace_id = format(ctx.trace_id, '032x')
        span_id = format(ctx.span_id, '016x')
    
    # Log request start
    log_extra = {
        "extra_fields": {
            "http": {
                "request": {
                    "method": request.method,
                    "path": request.url.path,
                    "headers": dict(request.headers)
                }
            },
            "event": {
                "action": "http_request_start"
            }
        }
    }
    logger.info(f"{request.method} {request.url.path}", extra=log_extra)
    
    # Process request
    response = await call_next(request)
    duration = time.time() - start_time
    
    # Update metrics
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code,
        service="backend-service"
    ).inc()
    
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path,
        service="backend-service"
    ).observe(duration)
    
    # Log request completion
    log_extra = {
        "extra_fields": {
            "http": {
                "request": {
                    "method": request.method,
                    "path": request.url.path
                },
                "response": {
                    "status_code": response.status_code,
                    "duration_ms": duration * 1000
                }
            },
            "event": {
                "action": "http_request_complete",
                "duration": duration
            }
        }
    }
    logger.info(
        f"{request.method} {request.url.path} - {response.status_code} ({duration*1000:.2f}ms)",
        extra=log_extra
    )
    
    return response


@app.get("/")
async def root():
    """Root endpoint"""
    with tracer.start_as_current_span("root-request") as span:
        span.set_attribute("endpoint", "/")
        
        logger.info("Root endpoint called", extra={
            "extra_fields": {
                "event": {"action": "root_endpoint"}
            }
        })
        
        return {
            "service": "backend-service",
            "version": "1.0.0",
            "endpoints": [
                "/health",
                "/metrics",
                "/call-frontend",
                "/call-frontend/redis",
                "/call-frontend/postgres",
                "/distributed-trace"
            ]
        }


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "backend-service",
        "version": "1.0.0"
    }


@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/call-frontend")
async def call_frontend():
    """
    Call frontend service - demonstrates service-to-service communication
    with trace context propagation
    """
    with tracer.start_as_current_span("call-frontend-service") as span:
        span.set_attribute("upstream.service", "frontend-service")
        span.set_attribute("upstream.endpoint", "/")
        
        logger.info("Calling frontend service", extra={
            "extra_fields": {
                "event": {"action": "upstream_call_start"},
                "upstream": {"service": "frontend-service", "endpoint": "/"}
            }
        })
        
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient() as client:
                # Context is automatically propagated via HTTPXClientInstrumentor
                response = await client.get(f"{FRONTEND_SERVICE_URL}/")
                
            duration = time.time() - start_time
            
            # Update upstream metrics
            UPSTREAM_REQUEST_COUNT.labels(
                upstream_service="frontend-service",
                method="GET",
                status=response.status_code
            ).inc()
            
            UPSTREAM_REQUEST_DURATION.labels(
                upstream_service="frontend-service",
                method="GET"
            ).observe(duration)
            
            logger.info("Frontend service responded", extra={
                "extra_fields": {
                    "event": {"action": "upstream_call_complete"},
                    "upstream": {
                        "service": "frontend-service",
                        "status_code": response.status_code,
                        "duration_ms": duration * 1000
                    }
                }
            })
            
            return {
                "status": "success",
                "upstream_service": "frontend-service",
                "upstream_response": response.json(),
                "response_time_ms": duration * 1000
            }
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            
            logger.error(f"Error calling frontend service: {str(e)}", extra={
                "extra_fields": {
                    "event": {"action": "upstream_call_error"},
                    "upstream": {"service": "frontend-service"},
                    "error": {"message": str(e)}
                }
            }, exc_info=True)
            
            raise HTTPException(
                status_code=503,
                detail=f"Frontend service unavailable: {str(e)}"
            )


@app.get("/call-frontend/{endpoint:path}")
async def call_frontend_endpoint(endpoint: str):
    """
    Call specific endpoint on frontend service
    Demonstrates parameterized service-to-service calls
    """
    with tracer.start_as_current_span("call-frontend-endpoint") as span:
        span.set_attribute("upstream.service", "frontend-service")
        span.set_attribute("upstream.endpoint", f"/{endpoint}")
        
        logger.info(f"Calling frontend service endpoint: /{endpoint}", extra={
            "extra_fields": {
                "event": {"action": "upstream_call_start"},
                "upstream": {"service": "frontend-service", "endpoint": f"/{endpoint}"}
            }
        })
        
        try:
            start_time = time.time()
            
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{FRONTEND_SERVICE_URL}/{endpoint}")
                
            duration = time.time() - start_time
            
            UPSTREAM_REQUEST_COUNT.labels(
                upstream_service="frontend-service",
                method="GET",
                status=response.status_code
            ).inc()
            
            UPSTREAM_REQUEST_DURATION.labels(
                upstream_service="frontend-service",
                method="GET"
            ).observe(duration)
            
            logger.info(f"Frontend service /{endpoint} responded", extra={
                "extra_fields": {
                    "event": {"action": "upstream_call_complete"},
                    "upstream": {
                        "service": "frontend-service",
                        "endpoint": f"/{endpoint}",
                        "status_code": response.status_code,
                        "duration_ms": duration * 1000
                    }
                }
            })
            
            return {
                "status": "success",
                "upstream_service": "frontend-service",
                "upstream_endpoint": f"/{endpoint}",
                "upstream_response": response.json(),
                "response_time_ms": duration * 1000
            }
            
        except httpx.HTTPStatusError as e:
            logger.warning(f"Frontend service returned error: {e.response.status_code}", extra={
                "extra_fields": {
                    "event": {"action": "upstream_call_error"},
                    "upstream": {
                        "service": "frontend-service",
                        "endpoint": f"/{endpoint}",
                        "status_code": e.response.status_code
                    }
                }
            })
            
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Frontend service error: {e.response.text}"
            )
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            
            logger.error(f"Error calling frontend service: {str(e)}", extra={
                "extra_fields": {
                    "event": {"action": "upstream_call_error"},
                    "upstream": {"service": "frontend-service", "endpoint": f"/{endpoint}"},
                    "error": {"message": str(e)}
                }
            }, exc_info=True)
            
            raise HTTPException(
                status_code=503,
                detail=f"Frontend service unavailable: {str(e)}"
            )


@app.get("/distributed-trace")
async def distributed_trace():
    """
    Endpoint that demonstrates full distributed tracing
    Makes multiple service-to-service calls
    """
    with tracer.start_as_current_span("distributed-trace-demo") as parent_span:
        parent_span.set_attribute("operation", "distributed_trace_demo")
        
        logger.info("Starting distributed trace demonstration", extra={
            "extra_fields": {
                "event": {"action": "distributed_trace_start"}
            }
        })
        
        results = {}
        
        # Call multiple endpoints to create a complex trace
        endpoints = ["redis", "postgres", "health"]
        
        for ep in endpoints:
            with tracer.start_as_current_span(f"call-{ep}") as span:
                span.set_attribute("endpoint", ep)
                
                try:
                    async with httpx.AsyncClient() as client:
                        response = await client.get(f"{FRONTEND_SERVICE_URL}/{ep}")
                        results[ep] = {
                            "status": "success",
                            "status_code": response.status_code
                        }
                        
                    logger.info(f"Called frontend /{ep}", extra={
                        "extra_fields": {
                            "event": {"action": "trace_step_complete"},
                            "step": {"name": ep, "status": "success"}
                        }
                    })
                    
                except Exception as e:
                    span.set_attribute("error", True)
                    span.record_exception(e)
                    results[ep] = {
                        "status": "error",
                        "error": str(e)
                    }
                    
                    logger.warning(f"Error calling /{ep}: {str(e)}", extra={
                        "extra_fields": {
                            "event": {"action": "trace_step_error"},
                            "step": {"name": ep, "status": "error", "error": str(e)}
                        }
                    })
        
        logger.info("Distributed trace demonstration complete", extra={
            "extra_fields": {
                "event": {"action": "distributed_trace_complete"},
                "results": results
            }
        })
        
        return {
            "status": "success",
            "operation": "distributed_trace_demo",
            "results": results,
            "message": "Check Jaeger UI to see the full distributed trace"
        }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
