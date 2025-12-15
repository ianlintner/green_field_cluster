# Architecture Overview

## System Architecture

The Greenfield Cluster provides a complete Kubernetes-based infrastructure stack designed for modern cloud-native applications.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Istio Service Mesh                       │
│                     (Traffic Management & Security)              │
└─────────────────────────────────────────────────────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
            ┌───────▼──────┐ ┌──▼────────┐ ┌▼──────────┐
            │   External   │ │  FastAPI  │ │ Internal  │
            │   Services   │ │    App    │ │ Services  │
            │   (Ingress)  │ └───────────┘ └───────────┘
            └──────────────┘      │              │
                                  │              │
        ┌─────────────────────────┼──────────────┼─────────────┐
        │                         │              │             │
   ┌────▼────┐             ┌─────▼──────┐  ┌───▼────────┐  ┌─▼──────────┐
   │Database │             │  Message   │  │Observability│  │  Security  │
   │ Layer   │             │   Queue    │  │   Stack     │  │   Layer    │
   └─────────┘             └────────────┘  └─────────────┘  └────────────┘
```

## Component Architecture

### 1. Data Layer

#### Redis (Caching & Session Storage)
- **Deployment Type**: StatefulSet (Master + Replicas)
- **Replicas**: 1 Master, 2 Replicas
- **Persistence**: PersistentVolumeClaim (1Gi)
- **Purpose**: 
  - Session storage
  - Caching layer
  - Real-time data structures

#### PostgreSQL (Relational Database)
- **Deployment Type**: StatefulSet
- **Replicas**: 3
- **Persistence**: PersistentVolumeClaim (5Gi per instance)
- **Purpose**:
  - Transactional data
  - Structured data storage
  - ACID compliance

#### MySQL (Alternative Relational Database)
- **Deployment Type**: StatefulSet
- **Replicas**: 3
- **Persistence**: PersistentVolumeClaim (5Gi per instance)
- **Purpose**:
  - Legacy application support
  - Specific MySQL features
  - Multi-database strategy

#### MongoDB (Document Database)
- **Deployment Type**: StatefulSet (Replica Set)
- **Replicas**: 3
- **Persistence**: 5Gi data + 1Gi config per instance
- **Purpose**:
  - Document storage
  - Flexible schema
  - JSON-like documents

### 2. Messaging Layer

#### Kafka + Zookeeper
- **Kafka Deployment**: StatefulSet (3 replicas)
- **Zookeeper Deployment**: StatefulSet (3 replicas)
- **Persistence**: 10Gi per Kafka broker, 2Gi per Zookeeper
- **Purpose**:
  - Event streaming
  - Message queue
  - Real-time data pipelines
  - Microservices communication

### 3. Service Mesh

#### Istio
- **Components**:
  - Istiod (Control Plane)
  - Ingress Gateway
  - Envoy Proxies (Sidecar)
- **Features**:
  - Traffic management
  - Security (mTLS)
  - Observability integration
  - Circuit breaking
  - Retry logic

### 4. Observability Stack

#### OpenTelemetry Collector
- **Deployment Type**: Deployment (2 replicas)
- **Purpose**:
  - Centralized telemetry collection
  - Trace aggregation
  - Metrics collection
  - Multi-backend export

#### Jaeger (Distributed Tracing)
- **Deployment Type**: All-in-one Deployment
- **Storage**: In-memory (production should use persistent backend)
- **Purpose**:
  - Trace visualization
  - Performance analysis
  - Dependency mapping
  - Latency investigation

#### Prometheus (Metrics)
- **Deployment Type**: Deployment
- **Storage**: EmptyDir (production should use persistent storage)
- **Purpose**:
  - Metrics collection
  - Time-series database
  - Alert evaluation
  - Service discovery

#### Grafana (Visualization)
- **Deployment Type**: Deployment
- **Data Sources**: Prometheus, Jaeger
- **Purpose**:
  - Dashboard creation
  - Metrics visualization
  - Alerting interface
  - Multi-source querying

### 5. Application Layer

#### FastAPI Example Application
- **Deployment Type**: Deployment (2 replicas)
- **Features**:
  - OpenTelemetry instrumentation
  - Prometheus metrics endpoint
  - Database connectivity examples
  - Kafka integration
  - Health checks
- **Purpose**:
  - Reference implementation
  - Integration testing
  - Demo application

### 6. Security Layer

#### Sealed Secrets
- **Deployment**: Controller in kube-system
- **Purpose**:
  - Encrypt secrets at rest
  - GitOps-friendly secrets
  - Asymmetric encryption
  - Safe to commit to Git

## Network Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Internet / Load Balancer              │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│                  Istio Ingress Gateway                    │
│                    (Port 80/443)                          │
└────────────────────────┬─────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────┐
│                    Istio Service Mesh                     │
│              (mTLS, Traffic Management)                   │
└──┬───────────┬────────────┬────────────┬─────────────┬───┘
   │           │            │            │             │
   │ App Layer │  Data Layer│ Messaging  │ Observability│
   │           │            │            │             │
┌──▼───┐   ┌──▼───┐    ┌──▼───┐    ┌──▼───┐     ┌──▼───┐
│FastAPI│   │Redis │    │Kafka │    │ OTel │     │Grafana│
│      │   │      │    │      │    │      │     │      │
│  ┌───┼───┤Postgres   │ZK    │    │Jaeger│     │Prom  │
│  │   │   │      │    │      │    │      │     │      │
└──┼───┘   │MySQL │    └──────┘    └──────┘     └──────┘
   │       │      │
   │       │MongoDB
   │       └──────┘
   │
   └──────► All services connect through ClusterIP
```

## Data Flow

### 1. Request Flow

```
Client Request
    │
    ▼
Istio Ingress Gateway
    │
    ▼
Istio Envoy Sidecar (FastAPI Pod)
    │
    ▼
FastAPI Application
    │
    ├──► Redis (Cache Check)
    │
    ├──► PostgreSQL (Transactional Data)
    │
    ├──► MySQL (Alternative Data)
    │
    ├──► MongoDB (Document Data)
    │
    └──► Kafka (Event Publishing)
```

### 2. Observability Flow

```
Application Instrumentation
    │
    ├──► OpenTelemetry SDK
    │       │
    │       ├──► Traces ──► OTel Collector ──► Jaeger
    │       │
    │       └──► Metrics ──► OTel Collector ──► Prometheus
    │
    └──► Prometheus Client
            │
            └──► Metrics ──► Prometheus

Grafana queries both Prometheus and Jaeger for visualization
```

### 3. Event Flow

```
FastAPI Application
    │
    ▼
Kafka Producer
    │
    ▼
Kafka Broker (Distributed)
    │
    ├──► Topic: test-topic (Partition 0)
    ├──► Topic: test-topic (Partition 1)
    └──► Topic: test-topic (Partition 2)
    │
    ▼
Kafka Consumer (Other Services)
```

## Security Architecture

### 1. Network Security

- **Istio mTLS**: Automatic mutual TLS between services
- **Network Policies**: Namespace isolation (can be configured)
- **Ingress Control**: Single entry point through Istio Gateway
- **Service-to-Service Auth**: Istio RBAC

### 2. Secrets Management

```
Developer
    │
    ▼
Create K8s Secret (local)
    │
    ▼
Seal with kubeseal (using cluster public key)
    │
    ▼
SealedSecret (encrypted, safe to commit)
    │
    ▼
Git Repository
    │
    ▼
kubectl apply -f sealed-secret.yaml
    │
    ▼
Sealed Secrets Controller (decrypts)
    │
    ▼
Kubernetes Secret (in cluster)
    │
    ▼
Application Pod (mounts secret)
```

### 3. Pod Security

- **Non-root containers**: Where possible
- **Read-only root filesystem**: For stateless apps
- **Resource limits**: CPU and memory limits set
- **Security contexts**: Configured appropriately

## Scalability Architecture

### Horizontal Scaling

- **Stateless Services**: Can scale freely (FastAPI, OTel Collector)
- **Stateful Services**: Use StatefulSets with stable network identities
- **Auto-scaling**: HPA can be configured based on metrics

### Vertical Scaling

- Resource requests and limits allow vertical scaling
- PVCs can be expanded (depends on storage class)

### Data Scaling

- **Redis**: Master-replica for read scaling
- **PostgreSQL/MySQL**: Read replicas can be added
- **MongoDB**: Replica set with eventual consistency
- **Kafka**: Partitioned topics for parallel processing

## High Availability

### Component HA Strategy

| Component | Replicas | Strategy |
|-----------|----------|----------|
| FastAPI | 2-3 | Load balanced |
| Redis | 1 Master + 2 Replicas | Failover |
| PostgreSQL | 3 | Synchronous replication |
| MySQL | 3 | Synchronous replication |
| MongoDB | 3 | Replica set with automatic failover |
| Kafka | 3 | Partition replication (factor: 3) |
| Zookeeper | 3 | Quorum-based |
| OTel Collector | 2 | Load balanced |
| Prometheus | 1-2 | Active-passive |
| Grafana | 1-2 | Active-passive |

## Resource Requirements

### Minimum Cluster Requirements

- **CPU**: 8 cores
- **Memory**: 16 GB
- **Storage**: 50 GB
- **Nodes**: 3 worker nodes

### Production Recommendations

- **CPU**: 16+ cores
- **Memory**: 32+ GB
- **Storage**: 200+ GB with SSD
- **Nodes**: 5+ worker nodes across availability zones

## Storage Architecture

### Storage Classes

- **Development**: Standard storage (HDD)
- **Production**: SSD-backed storage classes
- **Critical Data**: Regional persistent disks with replication

### Backup Strategy

- **Databases**: Regular pg_dump, mysqldump, mongodump
- **PVCs**: Snapshot-based backups
- **Cluster State**: Velero for disaster recovery
- **Frequency**: Daily incremental, weekly full

## Deployment Strategies

### Blue-Green Deployment

```yaml
# Support for blue-green through Istio VirtualService
# Weight-based traffic splitting
```

### Canary Deployment

```yaml
# Progressive rollout using Istio
# Gradual traffic shift: 5% → 25% → 50% → 100%
```

### Rolling Update

```yaml
# Default Kubernetes strategy
# MaxSurge: 1, MaxUnavailable: 0
# Zero-downtime deployments
```

## Monitoring Strategy

### Key Metrics

1. **Application Metrics**
   - Request rate
   - Error rate
   - Response time (p50, p95, p99)
   - Concurrent connections

2. **Infrastructure Metrics**
   - CPU utilization
   - Memory utilization
   - Disk I/O
   - Network throughput

3. **Database Metrics**
   - Connection pool usage
   - Query performance
   - Replication lag
   - Cache hit rate

4. **Business Metrics**
   - Active users
   - Transaction volume
   - Feature usage
   - Error rates by endpoint

## Future Enhancements

1. **Service Mesh Features**
   - Rate limiting
   - Circuit breakers
   - Fault injection
   - Advanced routing

2. **Observability**
   - Log aggregation (ELK/Loki)
   - APM integration
   - Custom dashboards
   - Alert policies

3. **Security**
   - OPA policy enforcement
   - Image scanning
   - Runtime security
   - Secret rotation automation

4. **Data Layer**
   - Database operators (e.g., Zalando Postgres Operator)
   - Backup automation
   - Read replicas
   - Connection pooling (PgBouncer)

5. **CI/CD Integration**
   - GitOps (ArgoCD/Flux)
   - Automated testing
   - Progressive delivery
   - Rollback automation
