# Architecture Overview

## System Architecture

The Greenfield Cluster is built on a layered architecture that separates concerns and promotes scalability.

## High-Level Architecture

```mermaid
graph TB
    subgraph "External Layer"
        LB[Load Balancer]
        DNS[DNS]
    end
    
    subgraph "Ingress Layer"
        IG[Istio Gateway]
        subgraph "Service Mesh"
            Envoy[Envoy Proxies]
        end
    end
    
    subgraph "Application Layer"
        App1[Service 1]
        App2[Service 2]
        App3[Service N]
        FastAPI[FastAPI Example]
    end
    
    subgraph "Data Layer"
        subgraph "Caching"
            Redis[Redis<br/>Master + Replicas]
        end
        subgraph "Relational"
            PG[PostgreSQL<br/>Cluster]
            MySQL[MySQL<br/>Cluster]
        end
        subgraph "Document"
            Mongo[MongoDB<br/>Replica Set]
        end
    end
    
    subgraph "Messaging Layer"
        Kafka[Kafka<br/>Brokers]
        ZK[Zookeeper<br/>Ensemble]
    end
    
    subgraph "Observability Layer"
        OTel[OpenTelemetry<br/>Collector]
        Jaeger[Jaeger<br/>Tracing]
        Prom[Prometheus<br/>Metrics]
        Grafana[Grafana<br/>Dashboards]
    end
    
    DNS --> LB
    LB --> IG
    IG --> Envoy
    Envoy --> App1
    Envoy --> App2
    Envoy --> App3
    Envoy --> FastAPI
    
    App1 --> Redis
    App1 --> PG
    App2 --> MySQL
    App3 --> Mongo
    FastAPI --> Redis
    FastAPI --> PG
    FastAPI --> MySQL
    FastAPI --> Mongo
    
    App1 --> Kafka
    App2 --> Kafka
    App3 --> Kafka
    FastAPI --> Kafka
    Kafka --> ZK
    
    App1 --> OTel
    App2 --> OTel
    App3 --> OTel
    FastAPI --> OTel
    
    OTel --> Jaeger
    OTel --> Prom
    Grafana --> Prom
    Grafana --> Jaeger
    
    style IG fill:#326CE5
    style Envoy fill:#326CE5
    style Redis fill:#DC382D
    style PG fill:#336791
    style MySQL fill:#4479A1
    style Mongo fill:#47A248
    style Kafka fill:#231F20
    style OTel fill:#FF6F00
    style Jaeger fill:#60D0E4
    style Prom fill:#E6522C
    style Grafana fill:#F46800
```

## Network Flow

### Request Flow

```mermaid
sequenceDiagram
    participant Client
    participant Istio Gateway
    participant Envoy Sidecar
    participant Application
    participant Database
    participant OTel Collector
    participant Jaeger
    
    Client->>Istio Gateway: HTTPS Request
    Istio Gateway->>Envoy Sidecar: Forward Request
    Note over Envoy Sidecar: mTLS Encryption
    Envoy Sidecar->>Application: HTTP Request
    Note over Application: Generate Trace
    Application->>Database: Query Data
    Database-->>Application: Return Data
    Application->>OTel Collector: Send Trace
    OTel Collector->>Jaeger: Store Trace
    Application-->>Envoy Sidecar: HTTP Response
    Envoy Sidecar-->>Istio Gateway: Forward Response
    Istio Gateway-->>Client: HTTPS Response
```

### Observability Data Flow

```mermaid
graph LR
    subgraph "Application"
        App[Application Code]
        OTelSDK[OpenTelemetry SDK]
    end
    
    subgraph "Collection"
        Collector[OTel Collector]
    end
    
    subgraph "Storage & Visualization"
        Jaeger[Jaeger<br/>Traces]
        Prometheus[Prometheus<br/>Metrics]
        Grafana[Grafana<br/>Dashboards]
    end
    
    App -->|Instrument| OTelSDK
    OTelSDK -->|OTLP/gRPC| Collector
    Collector -->|Traces| Jaeger
    Collector -->|Metrics| Prometheus
    Prometheus -->|Query| Grafana
    Jaeger -->|Query| Grafana
    
    style App fill:#009688
    style Collector fill:#FF6F00
    style Jaeger fill:#60D0E4
    style Prometheus fill:#E6522C
    style Grafana fill:#F46800
```

## Component Interactions

### Database Access Pattern

```mermaid
graph TD
    App[Application]
    
    subgraph "Data Access"
        Cache{Check Cache}
        Redis[Redis]
        DB{Select DB}
        PG[PostgreSQL]
        MySQL[MySQL]
        Mongo[MongoDB]
    end
    
    App --> Cache
    Cache -->|Hit| App
    Cache -->|Miss| DB
    DB -->|Relational| PG
    DB -->|Alternative| MySQL
    DB -->|Document| Mongo
    PG --> App
    MySQL --> App
    Mongo --> App
    
    style Cache fill:#FFD700
    style Redis fill:#DC382D
    style PG fill:#336791
    style MySQL fill:#4479A1
    style Mongo fill:#47A248
```

### Event-Driven Architecture

```mermaid
graph LR
    subgraph "Producers"
        Service1[Service 1]
        Service2[Service 2]
        Service3[Service 3]
    end
    
    subgraph "Message Broker"
        Kafka[Kafka Cluster]
        Topics[Topics:<br/>- orders<br/>- events<br/>- notifications]
    end
    
    subgraph "Consumers"
        Consumer1[Consumer 1]
        Consumer2[Consumer 2]
        Consumer3[Consumer 3]
    end
    
    Service1 -->|Publish| Kafka
    Service2 -->|Publish| Kafka
    Service3 -->|Publish| Kafka
    Kafka --> Topics
    Topics -->|Subscribe| Consumer1
    Topics -->|Subscribe| Consumer2
    Topics -->|Subscribe| Consumer3
    
    style Kafka fill:#231F20,color:#fff
    style Topics fill:#231F20,color:#fff
```

## Scaling Architecture

### Horizontal Scaling

```mermaid
graph TB
    subgraph "Scaling Tiers"
        subgraph "Stateless - Scale Freely"
            API[API Services<br/>2-10 replicas]
            OTel[OTel Collectors<br/>2-5 replicas]
        end
        
        subgraph "Stateful - Controlled Scaling"
            Redis[Redis<br/>1 Master + N Replicas]
            PG[PostgreSQL<br/>3-7 nodes]
            Kafka[Kafka<br/>3-9 brokers]
        end
    end
    
    HPA[Horizontal Pod<br/>Autoscaler]
    
    HPA -->|Auto Scale| API
    HPA -->|Auto Scale| OTel
    
    style API fill:#4CAF50
    style OTel fill:#FF6F00
    style Redis fill:#DC382D
    style PG fill:#336791
    style Kafka fill:#231F20,color:#fff
```

## Deployment Topology

### Multi-Zone Deployment

```mermaid
graph TB
    subgraph "Region: us-west-2"
        subgraph "AZ-1"
            K8s1[Kubernetes Node]
            PG1[PostgreSQL-0]
            Kafka1[Kafka-0]
            App1[App Replicas]
        end
        
        subgraph "AZ-2"
            K8s2[Kubernetes Node]
            PG2[PostgreSQL-1]
            Kafka2[Kafka-1]
            App2[App Replicas]
        end
        
        subgraph "AZ-3"
            K8s3[Kubernetes Node]
            PG3[PostgreSQL-2]
            Kafka3[Kafka-2]
            App3[App Replicas]
        end
    end
    
    LB[Load Balancer]
    
    LB --> App1
    LB --> App2
    LB --> App3
    
    PG1 -.->|Replicate| PG2
    PG2 -.->|Replicate| PG3
    PG3 -.->|Replicate| PG1
    
    Kafka1 -.->|Replicate| Kafka2
    Kafka2 -.->|Replicate| Kafka3
    Kafka3 -.->|Replicate| Kafka1
    
    style LB fill:#326CE5
    style K8s1 fill:#326CE5
    style K8s2 fill:#326CE5
    style K8s3 fill:#326CE5
```

## Security Architecture

### Zero Trust Network

```mermaid
graph TB
    subgraph "External"
        Client[Client]
    end
    
    subgraph "Edge Security"
        WAF[WAF]
        Gateway[Istio Gateway<br/>TLS Termination]
    end
    
    subgraph "Service Mesh"
        subgraph "mTLS Zone"
            Service1[Service 1<br/>+ Envoy]
            Service2[Service 2<br/>+ Envoy]
            Service3[Service 3<br/>+ Envoy]
        end
    end
    
    subgraph "Data Security"
        Secrets[Sealed Secrets]
        Encryption[Encryption at Rest]
    end
    
    subgraph "Access Control"
        RBAC[Kubernetes RBAC]
        NetworkPolicy[Network Policies]
    end
    
    Client -->|HTTPS| WAF
    WAF -->|HTTPS| Gateway
    Gateway -.->|mTLS| Service1
    Gateway -.->|mTLS| Service2
    Gateway -.->|mTLS| Service3
    Service1 -.->|mTLS| Service2
    Service2 -.->|mTLS| Service3
    
    Secrets --> Service1
    Secrets --> Service2
    Secrets --> Service3
    
    RBAC --> Service1
    RBAC --> Service2
    RBAC --> Service3
    
    NetworkPolicy --> Service1
    NetworkPolicy --> Service2
    NetworkPolicy --> Service3
    
    style WAF fill:#F44336
    style Gateway fill:#326CE5
    style Secrets fill:#9C27B0
    style RBAC fill:#FF9800
    style NetworkPolicy fill:#FF9800
```

## Resource Allocation

### Resource Tiers

| Tier | CPU Request | CPU Limit | Memory Request | Memory Limit | Use Case |
|------|-------------|-----------|----------------|--------------|----------|
| Small | 100m | 500m | 128Mi | 512Mi | Collectors, sidecars |
| Medium | 250m | 1000m | 512Mi | 1Gi | Applications, APIs |
| Large | 500m | 2000m | 1Gi | 4Gi | Databases, Kafka |
| XLarge | 1000m | 4000m | 2Gi | 8Gi | Heavy workloads |

### Storage Patterns

```mermaid
graph LR
    subgraph "Ephemeral Storage"
        EmptyDir[EmptyDir<br/>Temporary data]
    end
    
    subgraph "Persistent Storage"
        PVC[PersistentVolumeClaim]
        PV[PersistentVolume]
        Storage[Cloud Storage<br/>EBS, Persistent Disk, etc.]
    end
    
    Pod[Pod] --> EmptyDir
    Pod --> PVC
    PVC --> PV
    PV --> Storage
    
    style EmptyDir fill:#FFC107
    style PVC fill:#2196F3
    style PV fill:#2196F3
    style Storage fill:#4CAF50
```

## Design Principles

### 12-Factor App Compliance

1. **Codebase**: One codebase tracked in revision control
2. **Dependencies**: Explicitly declare and isolate dependencies
3. **Config**: Store config in the environment
4. **Backing Services**: Treat backing services as attached resources
5. **Build, Release, Run**: Strictly separate build and run stages
6. **Processes**: Execute the app as stateless processes
7. **Port Binding**: Export services via port binding
8. **Concurrency**: Scale out via the process model
9. **Disposability**: Maximize robustness with fast startup and graceful shutdown
10. **Dev/Prod Parity**: Keep development, staging, and production as similar as possible
11. **Logs**: Treat logs as event streams
12. **Admin Processes**: Run admin/management tasks as one-off processes

### Cloud Native Principles

- **Container-first**: All components containerized
- **Dynamically orchestrated**: Kubernetes manages lifecycle
- **Microservices-oriented**: Loosely coupled services
- **Observable**: Comprehensive telemetry
- **Resilient**: Self-healing and fault-tolerant
- **Declarative**: Infrastructure as code

## Next Steps

- [Deployment Methods](../deployment/methods.md)
- [Component Details](redis.md)
- [Security Overview](../security/overview.md)
