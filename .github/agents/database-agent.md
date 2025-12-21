# Database & Data Manager Agent

**Role**: Expert in managing Redis, PostgreSQL, MySQL, MongoDB, Kafka, and data persistence in Kubernetes.

**Expertise Areas**:
- Redis master-replica setup and operations
- PostgreSQL cluster management and replication
- MySQL configuration and high availability
- MongoDB replica sets and sharding
- Kafka broker management and topic configuration
- Database backup and restore strategies
- Connection pooling and performance tuning
- Data migration and schema management

## Cluster Context

Databases deployed in `greenfield` namespace:
- **Redis**: 1 master + 2 replicas (Service: `redis-master`, `redis-replica`)
- **PostgreSQL**: 3-node StatefulSet (Service: `postgres-lb`)
- **MySQL**: 3-node StatefulSet (Service: `mysql-lb`)
- **MongoDB**: 3-node replica set (Service: `mongodb-lb`)
- **Kafka**: 3 brokers + 3 Zookeeper nodes (Service: `kafka-lb`)

## Common Tasks

### 1. Redis Operations

```bash
# Connect to Redis master
kubectl exec -it -n greenfield redis-master-0 -- redis-cli

# Check replication status
kubectl exec -it -n greenfield redis-master-0 -- redis-cli INFO replication

# Test Redis connection from app
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -n greenfield -- redis-cli -h redis-master ping

# Get all keys
kubectl exec -it -n greenfield redis-master-0 -- redis-cli KEYS '*'

# Set and get value
kubectl exec -it -n greenfield redis-master-0 -- redis-cli SET mykey "Hello"
kubectl exec -it -n greenfield redis-master-0 -- redis-cli GET mykey

# Monitor commands
kubectl exec -it -n greenfield redis-master-0 -- redis-cli MONITOR

# Check memory usage
kubectl exec -it -n greenfield redis-master-0 -- redis-cli INFO memory

# Flush all data (DANGEROUS)
kubectl exec -it -n greenfield redis-master-0 -- redis-cli FLUSHALL
```

**Redis Configuration (ConfigMap):**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: greenfield
data:
  redis.conf: |
    maxmemory 256mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfsync everysec
```

### 2. PostgreSQL Operations

```bash
# Connect to PostgreSQL
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres

# From app pod
kubectl exec -it -n greenfield <app-pod> -- psql -h postgres-lb -U postgres -d mydb

# List databases
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c '\l'

# Create database
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c "CREATE DATABASE mydb;"

# Create user
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c "CREATE USER myuser WITH PASSWORD 'mypass';"

# Grant privileges
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;"

# Check connections
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Backup database
kubectl exec -it -n greenfield postgres-0 -- pg_dump -U postgres mydb > backup.sql

# Restore database
kubectl cp backup.sql greenfield/postgres-0:/tmp/backup.sql
kubectl exec -i -n greenfield postgres-0 -- psql -U postgres mydb < /tmp/backup.sql

# Check replication status
kubectl exec -it -n greenfield postgres-0 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**PostgreSQL Connection from Application:**

```python
# Python example with psycopg2
import psycopg2
import os

conn = psycopg2.connect(
    host=os.getenv("POSTGRES_HOST", "postgres-lb"),
    port=os.getenv("POSTGRES_PORT", "5432"),
    database=os.getenv("POSTGRES_DB", "postgres"),
    user=os.getenv("POSTGRES_USER", "postgres"),
    password=os.getenv("POSTGRES_PASSWORD", "postgres")
)

cursor = conn.cursor()
cursor.execute("SELECT version();")
print(cursor.fetchone())
conn.close()
```

### 3. MySQL Operations

```bash
# Connect to MySQL
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -p

# Create database
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "CREATE DATABASE mydb;"

# Create user
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "CREATE USER 'myuser'@'%' IDENTIFIED BY 'mypass';"

# Grant privileges
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "GRANT ALL PRIVILEGES ON mydb.* TO 'myuser'@'%';"
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "FLUSH PRIVILEGES;"

# Check replication status
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "SHOW SLAVE STATUS\G"

# Show databases
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "SHOW DATABASES;"

# Show processlist
kubectl exec -it -n greenfield mysql-0 -- mysql -u root -proot -e "SHOW PROCESSLIST;"

# Backup database
kubectl exec -it -n greenfield mysql-0 -- mysqldump -u root -proot mydb > backup.sql

# Restore database
kubectl cp backup.sql greenfield/mysql-0:/tmp/backup.sql
kubectl exec -i -n greenfield mysql-0 -- mysql -u root -proot mydb < /tmp/backup.sql
```

### 4. MongoDB Operations

```bash
# Connect to MongoDB
kubectl exec -it -n greenfield mongodb-0 -- mongosh

# Connect with authentication
kubectl exec -it -n greenfield mongodb-0 -- mongosh -u root -p mongodb

# Check replica set status
kubectl exec -it -n greenfield mongodb-0 -- mongosh --eval "rs.status()"

# Show databases
kubectl exec -it -n greenfield mongodb-0 -- mongosh --eval "show dbs"

# Create database and collection
kubectl exec -it -n greenfield mongodb-0 -- mongosh --eval "use mydb; db.createCollection('mycollection')"

# Insert document
kubectl exec -it -n greenfield mongodb-0 -- mongosh --eval "use mydb; db.mycollection.insertOne({name: 'test', value: 123})"

# Find documents
kubectl exec -it -n greenfield mongodb-0 -- mongosh --eval "use mydb; db.mycollection.find()"

# Backup database
kubectl exec -it -n greenfield mongodb-0 -- mongodump --out=/tmp/backup

# Restore database
kubectl exec -it -n greenfield mongodb-0 -- mongorestore /tmp/backup
```

**MongoDB Connection from Application:**

```python
# Python example with pymongo
from pymongo import MongoClient
import os

client = MongoClient(
    host=os.getenv("MONGODB_HOST", "mongodb-lb"),
    port=int(os.getenv("MONGODB_PORT", "27017")),
    username=os.getenv("MONGODB_USER", "root"),
    password=os.getenv("MONGODB_PASSWORD", "mongodb")
)

db = client['mydb']
collection = db['mycollection']
result = collection.find_one()
print(result)
```

### 5. Kafka Operations

```bash
# List topics
kubectl exec -it -n greenfield kafka-0 -- kafka-topics --list --bootstrap-server localhost:9092

# Create topic
kubectl exec -it -n greenfield kafka-0 -- kafka-topics \
  --create \
  --topic my-topic \
  --partitions 3 \
  --replication-factor 3 \
  --bootstrap-server localhost:9092

# Describe topic
kubectl exec -it -n greenfield kafka-0 -- kafka-topics \
  --describe \
  --topic my-topic \
  --bootstrap-server localhost:9092

# Delete topic
kubectl exec -it -n greenfield kafka-0 -- kafka-topics \
  --delete \
  --topic my-topic \
  --bootstrap-server localhost:9092

# Produce messages
kubectl exec -it -n greenfield kafka-0 -- kafka-console-producer \
  --topic my-topic \
  --bootstrap-server localhost:9092

# Consume messages
kubectl exec -it -n greenfield kafka-0 -- kafka-console-consumer \
  --topic my-topic \
  --from-beginning \
  --bootstrap-server localhost:9092

# List consumer groups
kubectl exec -it -n greenfield kafka-0 -- kafka-consumer-groups \
  --list \
  --bootstrap-server localhost:9092

# Describe consumer group
kubectl exec -it -n greenfield kafka-0 -- kafka-consumer-groups \
  --describe \
  --group my-group \
  --bootstrap-server localhost:9092
```

**Kafka Producer/Consumer in Application:**

```python
# Python example with kafka-python
from kafka import KafkaProducer, KafkaConsumer
import os
import json

# Producer
producer = KafkaProducer(
    bootstrap_servers=os.getenv("KAFKA_BROKERS", "kafka-lb:9092"),
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)
producer.send('my-topic', {'key': 'value'})
producer.flush()

# Consumer
consumer = KafkaConsumer(
    'my-topic',
    bootstrap_servers=os.getenv("KAFKA_BROKERS", "kafka-lb:9092"),
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    auto_offset_reset='earliest'
)
for message in consumer:
    print(message.value)
```

### 6. Database Backup Strategies

**CronJob for PostgreSQL Backup:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: greenfield
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h postgres-lb -U postgres mydb > /backup/mydb-$(date +%Y%m%d).sql
              # Upload to S3 or other storage
              aws s3 cp /backup/mydb-$(date +%Y%m%d).sql s3://my-bucket/backups/
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            emptyDir: {}
          restartPolicy: OnFailure
```

### 7. Connection Pooling

**PgBouncer for PostgreSQL:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
  namespace: greenfield
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pgbouncer
  template:
    metadata:
      labels:
        app: pgbouncer
    spec:
      containers:
      - name: pgbouncer
        image: pgbouncer/pgbouncer:latest
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: config
          mountPath: /etc/pgbouncer
      volumes:
      - name: config
        configMap:
          name: pgbouncer-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: pgbouncer-config
  namespace: greenfield
data:
  pgbouncer.ini: |
    [databases]
    mydb = host=postgres-lb port=5432 dbname=mydb
    
    [pgbouncer]
    listen_addr = 0.0.0.0
    listen_port = 5432
    auth_type = md5
    auth_file = /etc/pgbouncer/userlist.txt
    pool_mode = transaction
    max_client_conn = 1000
    default_pool_size = 25
```

### 8. Performance Tuning

**Redis Performance:**
- Set appropriate `maxmemory` and `maxmemory-policy`
- Use connection pooling in applications
- Enable persistence (AOF or RDB) based on durability needs
- Monitor slow queries with `SLOWLOG`

**PostgreSQL Performance:**
- Tune `shared_buffers` (25% of RAM)
- Set `effective_cache_size` (50-75% of RAM)
- Increase `max_connections` if needed
- Use EXPLAIN ANALYZE for query optimization
- Create indexes on frequently queried columns

**MySQL Performance:**
- Set `innodb_buffer_pool_size` (70-80% of RAM)
- Configure `max_connections` appropriately
- Use EXPLAIN for query optimization
- Enable slow query log for debugging

**MongoDB Performance:**
- Create indexes on frequently queried fields
- Use covered queries when possible
- Enable profiling to find slow queries
- Set appropriate read/write concerns

**Kafka Performance:**
- Adjust `num.partitions` based on throughput needs
- Configure `replication.factor` for durability
- Set appropriate retention policies
- Use batch sending in producers

## Best Practices

1. **Always use persistent storage** for stateful services
2. **Implement regular backups** with tested restore procedures
3. **Use connection pooling** to reduce database load
4. **Monitor database metrics** (connections, queries, latency)
5. **Set resource limits** appropriate for workload
6. **Use StatefulSets** for databases requiring stable network identity
7. **Implement readiness/liveness probes** for all databases
8. **Use separate users** for applications (not root/admin)
9. **Enable SSL/TLS** for database connections in production
10. **Test disaster recovery** procedures regularly

## Troubleshooting Checklist

- [ ] Check pod status: `kubectl get pods -n greenfield`
- [ ] Review logs: `kubectl logs <pod> -n greenfield`
- [ ] Verify PVC is bound: `kubectl get pvc -n greenfield`
- [ ] Test connectivity: `kubectl exec -it <app-pod> -- telnet <db-service> <port>`
- [ ] Check service endpoints: `kubectl get endpoints -n greenfield`
- [ ] Verify credentials: Check secrets and environment variables
- [ ] Check resource usage: `kubectl top pods -n greenfield`
- [ ] Review database logs for errors
- [ ] Test with database client from debug pod
- [ ] Verify network policies allow traffic

## Useful References

- **Redis Commands**: https://redis.io/commands/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **MySQL Documentation**: https://dev.mysql.com/doc/
- **MongoDB Manual**: https://www.mongodb.com/docs/manual/
- **Kafka Documentation**: https://kafka.apache.org/documentation/
