# MySQL

MySQL is a widely-used open-source relational database system providing an alternative to PostgreSQL in the Greenfield Cluster.

## Overview

The Greenfield Cluster includes MySQL with:

- **StatefulSet Deployment**: 3-node cluster configuration
- **Persistent Storage**: Dedicated volumes for each instance
- **Replication Support**: Master-slave replication capability
- **Health Monitoring**: Automated health checks
- **Configuration Management**: ConfigMap-based settings

## Architecture

### Configuration

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| **Version** | 8.0 | MySQL version |
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
mysql.greenfield.svc.cluster.local:3306

# Default credentials (CHANGE IN PRODUCTION!)
Database: myapp
Username: root
Password: mysql123
```

### Connecting from Applications

#### Python (mysql-connector)

```python
import mysql.connector

conn = mysql.connector.connect(
    host="mysql.greenfield.svc.cluster.local",
    port=3306,
    database="myapp",
    user="root",
    password="mysql123"
)
cursor = conn.cursor()
cursor.execute("SELECT VERSION();")
print(cursor.fetchone())
```

#### Node.js (mysql2)

```javascript
const mysql = require('mysql2/promise');

const connection = await mysql.createConnection({
  host: 'mysql.greenfield.svc.cluster.local',
  port: 3306,
  database: 'myapp',
  user: 'root',
  password: 'mysql123'
});
const [rows] = await connection.execute('SELECT NOW()');
```

### Using MySQL CLI

```bash
# Connect to MySQL
kubectl exec -it mysql-0 -n greenfield -- mysql -u root -pmysql123

# Common commands
SHOW DATABASES;
USE myapp;
SHOW TABLES;
DESCRIBE tablename;
EXIT;
```

## Operations

### Backup and Restore

```bash
# Backup database
kubectl exec mysql-0 -n greenfield -- mysqldump -u root -pmysql123 myapp > backup.sql

# Restore database
kubectl exec -i mysql-0 -n greenfield -- mysql -u root -pmysql123 myapp < backup.sql
```

### Monitoring

```bash
# Check status
kubectl get pods -n greenfield -l app=mysql

# View logs
kubectl logs mysql-0 -n greenfield

# Check processlist
kubectl exec mysql-0 -n greenfield -- mysql -u root -pmysql123 -e "SHOW PROCESSLIST;"
```

## Best Practices

1. **Secure Passwords**: Use strong root passwords in production
2. **Regular Backups**: Implement automated backup schedules
3. **Optimize Queries**: Use EXPLAIN to analyze query performance
4. **Connection Limits**: Configure appropriate max_connections
5. **InnoDB Buffer Pool**: Tune buffer_pool_size for performance

## Additional Resources

- [MySQL Documentation](https://dev.mysql.com/doc/)
- [PostgreSQL Component](postgres.md)
- [MongoDB Component](mongodb.md)
