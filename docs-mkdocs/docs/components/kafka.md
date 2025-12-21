# Kafka

Apache Kafka is a distributed event streaming platform used in the Greenfield Cluster for building real-time data pipelines and streaming applications.

## Overview

The Greenfield Cluster includes Kafka with:

- **Distributed Setup**: 3-broker Kafka cluster
- **Zookeeper Ensemble**: 3-node Zookeeper for coordination
- **Persistent Storage**: Dedicated volumes for data retention
- **High Throughput**: Optimized for high-volume messaging
- **Fault Tolerance**: Built-in replication and failover

## Architecture

### Configuration

| Component | Replicas | Resources | Storage |
|-----------|----------|-----------|---------|
| **Kafka Brokers** | 3 | 500m CPU, 1Gi RAM | 10Gi each |
| **Zookeeper** | 3 | 250m CPU, 512Mi RAM | 5Gi each |

## Usage

### Connection Information

```bash
# Kafka bootstrap servers
kafka-0.kafka.greenfield.svc.cluster.local:9092
kafka-1.kafka.greenfield.svc.cluster.local:9092
kafka-2.kafka.greenfield.svc.cluster.local:9092

# Or use service
kafka.greenfield.svc.cluster.local:9092

# Zookeeper ensemble
zookeeper-0.zookeeper.greenfield.svc.cluster.local:2181
zookeeper-1.zookeeper.greenfield.svc.cluster.local:2181
zookeeper-2.zookeeper.greenfield.svc.cluster.local:2181
```

### Producing Messages

#### Python (kafka-python)

```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['kafka.greenfield.svc.cluster.local:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

producer.send('events', {'type': 'user_signup', 'user_id': '123'})
producer.flush()
```

#### Node.js (kafkajs)

```javascript
const { Kafka } = require('kafkajs');

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['kafka.greenfield.svc.cluster.local:9092']
});

const producer = kafka.producer();
await producer.connect();
await producer.send({
  topic: 'events',
  messages: [
    { value: JSON.stringify({ type: 'user_signup', user_id: '123' }) }
  ]
});
```

### Consuming Messages

#### Python

```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'events',
    bootstrap_servers=['kafka.greenfield.svc.cluster.local:9092'],
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    group_id='my-consumer-group'
)

for message in consumer:
    print(f"Received: {message.value}")
```

#### Node.js

```javascript
const consumer = kafka.consumer({ groupId: 'my-consumer-group' });
await consumer.connect();
await consumer.subscribe({ topic: 'events' });

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    console.log('Received:', JSON.parse(message.value.toString()));
  }
});
```

### Using Kafka CLI

```bash
# Create topic
kubectl exec -it kafka-0 -n greenfield -- kafka-topics \
  --create --topic my-topic \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 2

# List topics
kubectl exec -it kafka-0 -n greenfield -- kafka-topics \
  --list --bootstrap-server localhost:9092

# Describe topic
kubectl exec -it kafka-0 -n greenfield -- kafka-topics \
  --describe --topic my-topic \
  --bootstrap-server localhost:9092

# Produce messages
kubectl exec -it kafka-0 -n greenfield -- kafka-console-producer \
  --topic my-topic \
  --bootstrap-server localhost:9092

# Consume messages
kubectl exec -it kafka-0 -n greenfield -- kafka-console-consumer \
  --topic my-topic \
  --from-beginning \
  --bootstrap-server localhost:9092
```

## Operations

### Topic Management

```bash
# List consumer groups
kubectl exec kafka-0 -n greenfield -- kafka-consumer-groups \
  --list --bootstrap-server localhost:9092

# Describe consumer group
kubectl exec kafka-0 -n greenfield -- kafka-consumer-groups \
  --describe --group my-consumer-group \
  --bootstrap-server localhost:9092

# Delete topic
kubectl exec kafka-0 -n greenfield -- kafka-topics \
  --delete --topic my-topic \
  --bootstrap-server localhost:9092
```

### Monitoring

```bash
# Check broker logs
kubectl logs kafka-0 -n greenfield

# Check Zookeeper
kubectl exec zookeeper-0 -n greenfield -- zkCli.sh ls /brokers/ids

# Monitor lag
kubectl exec kafka-0 -n greenfield -- kafka-consumer-groups \
  --describe --group my-group --bootstrap-server localhost:9092
```

## Best Practices

1. **Partitioning Strategy**: Choose partition keys wisely for distribution
2. **Replication Factor**: Use replication factor of 3 for production
3. **Consumer Groups**: Use consumer groups for load distribution
4. **Retention Policy**: Configure appropriate retention based on use case
5. **Monitoring**: Track consumer lag and broker health
6. **Idempotent Producers**: Enable idempotence for exactly-once semantics

## Common Use Cases

### Event Sourcing

```python
# Store events
producer.send('user-events', {
    'event_type': 'user_created',
    'user_id': '123',
    'timestamp': '2024-01-01T12:00:00Z',
    'data': {'name': 'John', 'email': 'john@example.com'}
})
```

### Stream Processing

```python
# Process events in real-time
for message in consumer:
    event = message.value
    if event['type'] == 'order_created':
        process_order(event['order_id'])
```

### Log Aggregation

```python
# Centralized logging
producer.send('application-logs', {
    'service': 'api',
    'level': 'ERROR',
    'message': 'Failed to process request',
    'timestamp': '2024-01-01T12:00:00Z'
})
```

## Additional Resources

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Redis Component](redis.md)
- [OpenTelemetry Component](otel.md)
