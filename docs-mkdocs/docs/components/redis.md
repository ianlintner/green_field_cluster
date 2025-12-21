# Redis

Redis is an in-memory data structure store used as a database, cache, message broker, and streaming engine in the Greenfield Cluster.

## Overview

The Greenfield Cluster includes a Redis deployment with:

- **Master-Replica Architecture**: 1 master + 2 replicas for high availability
- **Persistent Storage**: Data persisted to disk using StatefulSets
- **Configuration Management**: ConfigMap-based configuration
- **Health Monitoring**: Liveness and readiness probes

## Architecture

### Deployment Structure

```
┌─────────────────────────────────────────┐
│          Redis Architecture             │
│                                         │
│  ┌──────────────┐                      │
│  │  Redis       │                      │
│  │  Master      │                      │
│  │  (Primary)   │                      │
│  └──────┬───────┘                      │
│         │                               │
│         │ Replication                   │
│    ┌────┴─────┐                        │
│    │          │                        │
│  ┌─▼────┐  ┌─▼────┐                   │
│  │Replica│  │Replica│                  │
│  │  #1   │  │  #2   │                  │
│  └───────┘  └───────┘                  │
│                                         │
│  Application connects to:               │
│  - Master: redis-master (writes)       │
│  - Service: redis-service (reads)      │
└─────────────────────────────────────────┘
```

### Configuration

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| **Version** | 7.2-alpine | Redis version |
| **Master Replicas** | 1 | Number of master instances |
| **Replica Count** | 2 | Number of read replicas |
| **CPU Request** | 100m | Minimum CPU |
| **CPU Limit** | 500m | Maximum CPU |
| **Memory Request** | 256Mi | Minimum memory |
| **Memory Limit** | 512Mi | Maximum memory |
| **Storage** | 1Gi per instance | Persistent storage size |

## Features

### Persistence

Redis uses both RDB (Redis Database) and AOF (Append Only File) persistence:

```conf
# RDB Persistence
save 900 1      # Save if 1 key changed in 900 seconds
save 300 10     # Save if 10 keys changed in 300 seconds
save 60 10000   # Save if 10000 keys changed in 60 seconds

# AOF Persistence
appendonly yes
appendfsync everysec
```

### Replication

Read replicas automatically sync from the master:

```bash
# Replicas connect to master
redis-server --replicaof redis-master 6379
```

### Health Checks

**Liveness Probe**: TCP socket check on port 6379  
**Readiness Probe**: `redis-cli ping` command

## Usage

### Connection Information

**Service Endpoints:**

```yaml
# Master service (read/write)
redis-master.greenfield.svc.cluster.local:6379

# Replica service (read-only)
redis-replica.greenfield.svc.cluster.local:6379

# General service (load-balanced)
redis-service.greenfield.svc.cluster.local:6379
```

### Connecting from Applications

#### Python (redis-py)

```python
import redis

# Write to master
master = redis.Redis(
    host='redis-master.greenfield.svc.cluster.local',
    port=6379,
    decode_responses=True
)
master.set('key', 'value')

# Read from replica
replica = redis.Redis(
    host='redis-replica.greenfield.svc.cluster.local',
    port=6379,
    decode_responses=True
)
value = replica.get('key')
```

#### Node.js (ioredis)

```javascript
const Redis = require('ioredis');

// Write to master
const master = new Redis({
  host: 'redis-master.greenfield.svc.cluster.local',
  port: 6379
});
await master.set('key', 'value');

// Read from replica
const replica = new Redis({
  host: 'redis-replica.greenfield.svc.cluster.local',
  port: 6379
});
const value = await replica.get('key');
```

#### Go (go-redis)

```go
package main

import (
    "context"
    "github.com/redis/go-redis/v9"
)

func main() {
    ctx := context.Background()
    
    // Write to master
    master := redis.NewClient(&redis.Options{
        Addr: "redis-master.greenfield.svc.cluster.local:6379",
    })
    master.Set(ctx, "key", "value", 0)
    
    // Read from replica
    replica := redis.NewClient(&redis.Options{
        Addr: "redis-replica.greenfield.svc.cluster.local:6379",
    })
    val := replica.Get(ctx, "key")
}
```

### Using Redis CLI

```bash
# Connect to master
kubectl exec -it redis-master-0 -n greenfield -- redis-cli

# Basic commands
> SET mykey "Hello"
> GET mykey
> EXISTS mykey
> DEL mykey
> KEYS *

# Check replication info
> INFO replication

# Monitor commands
> MONITOR
```

## Operations

### Scaling

#### Scale Read Replicas

```bash
# Using kubectl
kubectl scale statefulset redis-replica -n greenfield --replicas=3

# Using kustomize patch
# In overlays/prod/kustomization.yaml
replicas:
  - name: redis-replica
    count: 3
```

#### Vertical Scaling

Update resource limits in overlay patches:

```yaml
# patches/redis-resources.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-master
spec:
  template:
    spec:
      containers:
        - name: redis
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
```

### Backup and Restore

#### Manual Backup

```bash
# Backup RDB file
kubectl exec redis-master-0 -n greenfield -- redis-cli SAVE
kubectl cp greenfield/redis-master-0:/data/dump.rdb ./backup-$(date +%Y%m%d).rdb

# Backup AOF file
kubectl cp greenfield/redis-master-0:/data/appendonly.aof ./backup-$(date +%Y%m%d).aof
```

#### Restore from Backup

```bash
# Copy backup to pod
kubectl cp ./backup-20240101.rdb greenfield/redis-master-0:/data/dump.rdb

# Restart Redis
kubectl delete pod redis-master-0 -n greenfield
```

### Monitoring

#### Check Status

```bash
# Check pod status
kubectl get pods -n greenfield -l app=redis

# Check StatefulSet
kubectl get statefulset -n greenfield

# View logs
kubectl logs redis-master-0 -n greenfield
kubectl logs redis-replica-0 -n greenfield
```

#### Redis Metrics

```bash
# Connect and get info
kubectl exec -it redis-master-0 -n greenfield -- redis-cli INFO

# Key metrics to monitor:
# - used_memory
# - connected_clients
# - total_commands_processed
# - keyspace_hits / keyspace_misses (hit rate)
# - evicted_keys
# - expired_keys
```

#### Prometheus Metrics

Redis exports metrics for Prometheus. View at:
```
http://<pod-ip>:6379/metrics
```

## Configuration

### Custom Configuration

Modify the Redis ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
data:
  redis.conf: |
    # Memory Management
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    
    # Persistence
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfsync everysec
    
    # Replication
    replica-read-only yes
    
    # Security (in production, use stronger password)
    # requirepass <strong-password>
    
    # Performance
    tcp-backlog 511
    timeout 0
    tcp-keepalive 300
```

### Environment-Specific Settings

**Development:**
- Minimal resources
- Single replica
- Shorter persistence intervals

**Production:**
- Full resources
- Multiple replicas (3+)
- Stricter persistence
- Password authentication

## Security

### Authentication

Enable password authentication:

```yaml
# Create secret
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
type: Opaque
stringData:
  password: <strong-password>
```

```yaml
# Update ConfigMap
data:
  redis.conf: |
    requirepass <password>
```

### Network Policies

Restrict access to Redis:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-network-policy
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: fastapi-app
      ports:
        - protocol: TCP
          port: 6379
```

## Troubleshooting

### Common Issues

**Pods Not Starting**

```bash
# Check pod events
kubectl describe pod redis-master-0 -n greenfield

# Check logs
kubectl logs redis-master-0 -n greenfield

# Common causes:
# - PVC not bound (check storage class)
# - Resource constraints (check node resources)
# - Configuration errors (check ConfigMap)
```

**Replication Not Working**

```bash
# Check master
kubectl exec redis-master-0 -n greenfield -- redis-cli INFO replication

# Should show connected replicas
# If not, check:
# - Network connectivity
# - Master service DNS
# - Replica pod logs
```

**High Memory Usage**

```bash
# Check memory usage
kubectl exec redis-master-0 -n greenfield -- redis-cli INFO memory

# Solutions:
# - Enable eviction policy (maxmemory-policy)
# - Increase memory limits
# - Clean up unused keys
```

**Slow Performance**

```bash
# Check slow log
kubectl exec redis-master-0 -n greenfield -- redis-cli SLOWLOG GET 10

# Common causes:
# - Large key operations
# - Too many connected clients
# - Disk I/O issues (AOF fsync)
# - Memory swapping
```

## Performance Tuning

### Memory Optimization

```conf
# Eviction policies
maxmemory 512mb
maxmemory-policy allkeys-lru  # Good for cache
# maxmemory-policy volatile-lru  # Good for mixed use
# maxmemory-policy noeviction  # Good for data store

# Memory efficiency
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
```

### Persistence Tuning

```conf
# For cache (fast, less durable)
save ""
appendonly no

# For data store (slower, more durable)
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync always

# Balanced (recommended)
save 60 1000
appendonly yes
appendfsync everysec
```

## Best Practices

1. **Use Read Replicas**: Distribute read load across replicas
2. **Enable Persistence**: For non-cache use cases
3. **Set Memory Limits**: Prevent OOM kills
4. **Monitor Hit Rate**: Aim for >90% cache hit rate
5. **Use Connection Pooling**: In applications
6. **Implement Key Expiration**: For cache use cases
7. **Regular Backups**: For production data
8. **Security**: Enable authentication in production

## Use Cases

### Caching

```python
import redis
r = redis.Redis(host='redis-master.greenfield.svc.cluster.local')

# Cache with TTL
r.setex('user:1000', 3600, '{"name":"John","email":"john@example.com"}')

# Get cached data
user = r.get('user:1000')
```

### Session Store

```python
# Store session
r.hmset('session:abc123', {
    'user_id': '1000',
    'username': 'john',
    'last_activity': '2024-01-01T12:00:00'
})
r.expire('session:abc123', 1800)  # 30 min TTL
```

### Rate Limiting

```python
def check_rate_limit(user_id, limit=100, window=60):
    key = f'rate:{user_id}'
    current = r.incr(key)
    if current == 1:
        r.expire(key, window)
    return current <= limit
```

### Pub/Sub Messaging

```python
# Publisher
r.publish('notifications', 'New message!')

# Subscriber
pubsub = r.pubsub()
pubsub.subscribe('notifications')
for message in pubsub.listen():
    print(message)
```

## Additional Resources

- [Redis Documentation](https://redis.io/documentation)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)
- [Redis Persistence](https://redis.io/docs/management/persistence/)
- [Redis Replication](https://redis.io/docs/management/replication/)

## Related Components

- [PostgreSQL](postgres.md) - Relational database
- [Kafka](kafka.md) - Message broker
- [Grafana](grafana.md) - Monitoring dashboards
- [Prometheus](prometheus.md) - Metrics collection
