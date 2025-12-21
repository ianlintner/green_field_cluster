# PostgreSQL

PostgreSQL is a powerful, open-source relational database system used in the Greenfield Cluster for transactional data storage.

## Overview

The Greenfield Cluster includes PostgreSQL with:

- **StatefulSet Deployment**: 3-node cluster for high availability
- **Persistent Storage**: Each instance has dedicated persistent volumes
- **Automatic Initialization**: Schema setup via init scripts
- **Health Monitoring**: Liveness and readiness probes
- **Configuration Management**: ConfigMap-based configuration

## Architecture

### Configuration

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| **Version** | 16-alpine | PostgreSQL version |
| **Replicas** | 3 | Number of instances |
| **CPU Request** | 250m | Minimum CPU |
| **CPU Limit** | 1000m | Maximum CPU |
| **Memory Request** | 512Mi | Minimum memory |
| **Memory Limit** | 1Gi | Maximum memory |
| **Storage** | 5Gi per instance | Persistent storage |

## Usage

### Connection Information

```bash
# Service endpoint
postgres.greenfield.svc.cluster.local:5432

# Default credentials (CHANGE IN PRODUCTION!)
Database: myapp
Username: postgres
Password: postgres123
```

### Connecting from Applications

#### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="postgres.greenfield.svc.cluster.local",
    port=5432,
    database="myapp",
    user="postgres",
    password="postgres123"
)
cursor = conn.cursor()
cursor.execute("SELECT version();")
print(cursor.fetchone())
```

#### Node.js (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'postgres.greenfield.svc.cluster.local',
  port: 5432,
  database: 'myapp',
  user: 'postgres',
  password: 'postgres123'
});
await client.connect();
const res = await client.query('SELECT NOW()');
```

### Using psql CLI

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n greenfield -- psql -U postgres

# Common commands
\l                # List databases
\c myapp          # Connect to database
\dt               # List tables
\d tablename      # Describe table
\q                # Quit
```

## Operations

### Backup and Restore

```bash
# Backup database
kubectl exec postgres-0 -n greenfield -- pg_dump -U postgres myapp > backup.sql

# Restore database
kubectl exec -i postgres-0 -n greenfield -- psql -U postgres myapp < backup.sql
```

### Monitoring

```bash
# Check status
kubectl get pods -n greenfield -l app=postgres

# View logs
kubectl logs postgres-0 -n greenfield

# Check connections
kubectl exec postgres-0 -n greenfield -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

## Best Practices

1. **Change Default Password**: Use strong passwords in production
2. **Regular Backups**: Implement automated backup strategy
3. **Connection Pooling**: Use PgBouncer or application-level pooling
4. **Monitor Performance**: Track slow queries and connection counts
5. **Proper Indexing**: Create indexes for frequently queried columns

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Redis Component](redis.md)
- [MongoDB Component](mongodb.md)
