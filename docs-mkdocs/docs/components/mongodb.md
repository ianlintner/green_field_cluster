# MongoDB

MongoDB is a document-oriented NoSQL database system used in the Greenfield Cluster for flexible, schema-less data storage.

## Overview

The Greenfield Cluster includes MongoDB with:

- **Replica Set Configuration**: 3-node replica set for high availability
- **Persistent Storage**: Dedicated volumes for each replica
- **Automatic Failover**: Built-in replica set failover
- **Health Monitoring**: Liveness and readiness probes
- **Configuration Management**: ConfigMap-based configuration

## Architecture

### Configuration

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| **Version** | 7.0 | MongoDB version |
| **Replicas** | 3 | Replica set members |
| **CPU Request** | 250m | Minimum CPU |
| **CPU Limit** | 1000m | Maximum CPU |
| **Memory Request** | 512Mi | Minimum memory |
| **Memory Limit** | 1Gi | Maximum memory |
| **Storage** | 5Gi per instance | Persistent storage |

## Usage

### Connection Information

```bash
# Service endpoint
mongodb.greenfield.svc.cluster.local:27017

# Connection string
mongodb://mongodb-0.mongodb.greenfield.svc.cluster.local:27017,mongodb-1.mongodb.greenfield.svc.cluster.local:27017,mongodb-2.mongodb.greenfield.svc.cluster.local:27017/myapp?replicaSet=rs0

# Default credentials (CHANGE IN PRODUCTION!)
Username: admin
Password: mongo123
```

### Connecting from Applications

#### Python (pymongo)

```python
from pymongo import MongoClient

client = MongoClient(
    host="mongodb.greenfield.svc.cluster.local",
    port=27017,
    username="admin",
    password="mongo123"
)
db = client.myapp
collection = db.users
result = collection.find_one({"name": "John"})
```

#### Node.js (mongodb)

```javascript
const { MongoClient } = require('mongodb');

const client = new MongoClient(
  'mongodb://admin:mongo123@mongodb.greenfield.svc.cluster.local:27017/myapp'
);
await client.connect();
const db = client.db('myapp');
const collection = db.collection('users');
const result = await collection.findOne({ name: 'John' });
```

### Using Mongo Shell

```bash
# Connect to MongoDB
kubectl exec -it mongodb-0 -n greenfield -- mongosh -u admin -p mongo123

# Common commands
show dbs
use myapp
show collections
db.users.findOne()
db.users.insertOne({name: "John", email: "john@example.com"})
exit
```

## Operations

### Backup and Restore

```bash
# Backup database
kubectl exec mongodb-0 -n greenfield -- mongodump --username=admin --password=mongo123 --out=/tmp/backup
kubectl cp greenfield/mongodb-0:/tmp/backup ./mongodb-backup

# Restore database
kubectl cp ./mongodb-backup greenfield/mongodb-0:/tmp/restore
kubectl exec mongodb-0 -n greenfield -- mongorestore --username=admin --password=mongo123 /tmp/restore
```

### Monitoring

```bash
# Check replica set status
kubectl exec mongodb-0 -n greenfield -- mongosh -u admin -p mongo123 --eval "rs.status()"

# View logs
kubectl logs mongodb-0 -n greenfield

# Check database stats
kubectl exec mongodb-0 -n greenfield -- mongosh -u admin -p mongo123 --eval "db.stats()"
```

## Best Practices

1. **Replica Set**: Always use replica sets for production
2. **Indexes**: Create appropriate indexes for query performance
3. **Authentication**: Enable and enforce authentication
4. **Backup Strategy**: Regular automated backups
5. **Connection Pooling**: Configure appropriate pool sizes
6. **Schema Design**: Design for query patterns, not normalization

## Additional Resources

- [MongoDB Documentation](https://docs.mongodb.com/)
- [PostgreSQL Component](postgres.md)
- [Redis Component](redis.md)
