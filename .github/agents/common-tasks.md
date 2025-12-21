# Common Tasks - Quick Reference

This document provides ready-to-use commands and code examples for frequently performed tasks in the Greenfield Cluster.

## Quick Navigation

- [Deployment Tasks](#deployment-tasks)
- [Debugging Tasks](#debugging-tasks)
- [Database Operations](#database-operations)
- [Observability Tasks](#observability-tasks)
- [Security Tasks](#security-tasks)
- [Networking Tasks](#networking-tasks)
- [Maintenance Tasks](#maintenance-tasks)

## Deployment Tasks

### Deploy the Cluster

```bash
# Using Kustomize - Development
kubectl apply -k kustomize/overlays/dev/

# Using Kustomize - Production
kubectl apply -k kustomize/overlays/prod/

# Using Helm
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace

# Using Make
make deploy-dev
make deploy-prod
```

### Deploy a New Application

```bash
# Create namespace
kubectl create namespace my-app

# Enable Istio injection
kubectl label namespace my-app istio-injection=enabled

# Apply manifests
kubectl apply -f deployment.yaml -n my-app

# Check deployment status
kubectl get pods -n my-app
kubectl rollout status deployment/my-app -n my-app
```

### Update Application Image

```bash
# Set new image
kubectl set image deployment/my-app my-app=my-app:v2 -n greenfield

# Watch rollout
kubectl rollout status deployment/my-app -n greenfield

# Rollback if needed
kubectl rollout undo deployment/my-app -n greenfield
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment my-app --replicas=5 -n greenfield

# Autoscaling
kubectl autoscale deployment my-app \
  --min=2 --max=10 --cpu-percent=80 \
  -n greenfield

# Check autoscaler
kubectl get hpa -n greenfield
```

## Debugging Tasks

### Check Pod Status and Logs

```bash
# Get pod status
kubectl get pods -n greenfield
kubectl get pods -n greenfield -o wide
kubectl describe pod <pod-name> -n greenfield

# View logs
kubectl logs <pod-name> -n greenfield
kubectl logs <pod-name> -n greenfield --previous
kubectl logs <pod-name> -n greenfield -f --tail=100
kubectl logs -l app=my-app -n greenfield --tail=50

# Execute commands in pod
kubectl exec -it <pod-name> -n greenfield -- /bin/bash
kubectl exec -it <pod-name> -n greenfield -- env
```

### Debug Network Issues

```bash
# Create debug pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n greenfield -- /bin/bash

# Test connectivity
kubectl exec -it <pod-name> -n greenfield -- curl http://my-service:8080

# Check DNS
kubectl exec -it <pod-name> -n greenfield -- nslookup my-service

# Check service endpoints
kubectl get endpoints -n greenfield
kubectl describe service my-service -n greenfield

# Port forward for testing
kubectl port-forward <pod-name> -n greenfield 8080:8080
```

### Check Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n greenfield
kubectl top pods -n greenfield --sort-by=cpu
kubectl top pods -n greenfield --sort-by=memory

# Get resource requests and limits
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

## Database Operations

### PostgreSQL

```bash
# Connect to PostgreSQL
kubectl exec -it postgres-0 -n greenfield -- psql -U postgres

# Create database
kubectl exec -it postgres-0 -n greenfield -- psql -U postgres -c "CREATE DATABASE mydb;"

# Backup database
kubectl exec postgres-0 -n greenfield -- pg_dump -U postgres mydb > backup.sql

# Restore database
kubectl cp backup.sql greenfield/postgres-0:/tmp/backup.sql
kubectl exec -it postgres-0 -n greenfield -- psql -U postgres mydb < /tmp/backup.sql
```

### Redis

```bash
# Connect to Redis
kubectl exec -it redis-master-0 -n greenfield -- redis-cli

# Check replication
kubectl exec -it redis-master-0 -n greenfield -- redis-cli INFO replication

# Test from another pod
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -n greenfield -- \
  redis-cli -h redis-master ping
```

### MongoDB

```bash
# Connect to MongoDB
kubectl exec -it mongodb-0 -n greenfield -- mongosh -u root -p mongodb

# Check replica set status
kubectl exec -it mongodb-0 -n greenfield -- mongosh --eval "rs.status()"

# Backup
kubectl exec mongodb-0 -n greenfield -- mongodump --out=/tmp/backup
```

### MySQL

```bash
# Connect to MySQL
kubectl exec -it mysql-0 -n greenfield -- mysql -u root -proot

# Create database
kubectl exec -it mysql-0 -n greenfield -- mysql -u root -proot -e "CREATE DATABASE mydb;"

# Backup
kubectl exec mysql-0 -n greenfield -- mysqldump -u root -proot mydb > backup.sql
```

### Kafka

```bash
# List topics
kubectl exec -it kafka-0 -n greenfield -- \
  kafka-topics --list --bootstrap-server localhost:9092

# Create topic
kubectl exec -it kafka-0 -n greenfield -- \
  kafka-topics --create --topic my-topic --partitions 3 --replication-factor 3 \
  --bootstrap-server localhost:9092

# Produce messages
kubectl exec -it kafka-0 -n greenfield -- \
  kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Consume messages
kubectl exec -it kafka-0 -n greenfield -- \
  kafka-console-consumer --topic my-topic --from-beginning \
  --bootstrap-server localhost:9092
```

## Observability Tasks

### Access Observability Tools

```bash
# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090
# Access: http://localhost:9090

# Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000
# Access: http://localhost:3000 (admin/admin)

# Jaeger
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686
# Access: http://localhost:16686

# Kiali
kubectl port-forward -n greenfield svc/kiali 20001:20001
# Access: http://localhost:20001/kiali
```

### Query Prometheus Metrics

```promql
# CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="greenfield"}[5m])) by (pod)

# Memory usage
sum(container_memory_usage_bytes{namespace="greenfield"}) by (pod)

# HTTP request rate
sum(rate(http_requests_total{namespace="greenfield"}[5m])) by (service)

# Error rate
sum(rate(http_requests_total{status=~"5..",namespace="greenfield"}[5m])) / 
sum(rate(http_requests_total{namespace="greenfield"}[5m]))

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### View Application Traces

```bash
# Port forward to Jaeger
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686

# Query traces via API
curl 'http://localhost:16686/api/traces?service=my-service&limit=20'

# Get trace by ID
curl 'http://localhost:16686/api/traces/<trace-id>'
```

## Security Tasks

### Manage Secrets with Sealed Secrets

```bash
# Create and seal a secret
kubectl create secret generic my-secret \
  --from-literal=password=mysecret \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml -n greenfield

# Verify secret was created
kubectl get secret my-secret -n greenfield

# Get secret value
kubectl get secret my-secret -n greenfield -o jsonpath='{.data.password}' | base64 -d
```

### Configure SSL/TLS Certificate

```bash
# Create certificate
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: istio-system
spec:
  secretName: my-app-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
EOF

# Check certificate status
kubectl get certificate -n istio-system
kubectl describe certificate my-app-tls -n istio-system

# View certificate details
kubectl get secret my-app-tls-cert -n istio-system -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -text -noout
```

### Setup Authentication

```bash
# Install authentication with Azure AD
make auth.install PROVIDER=azuread DOMAIN=example.com

# Protect an application
make auth.protect APP=myapp HOST=myapp.example.com POLICY="group:developers"

# Verify setup
make auth.doctor
```

## Networking Tasks

### Create Istio Gateway and VirtualService

```bash
# Create gateway
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-app-gateway
  namespace: greenfield
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.example.com"
EOF

# Create VirtualService
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app-vs
  namespace: greenfield
spec:
  hosts:
  - "myapp.example.com"
  gateways:
  - my-app-gateway
  http:
  - route:
    - destination:
        host: my-app
        port:
          number: 8080
EOF

# Check status
kubectl get gateway -n greenfield
kubectl get virtualservice -n greenfield
```

### Check Istio Configuration

```bash
# Analyze Istio config
istioctl analyze -n greenfield

# Check proxy status
istioctl proxy-status

# View proxy config
istioctl proxy-config routes <pod-name> -n greenfield
istioctl proxy-config clusters <pod-name> -n greenfield

# Check if sidecar is injected
kubectl get pod <pod-name> -n greenfield -o jsonpath='{.spec.containers[*].name}'
```

### Get Ingress Gateway IP/Hostname

```bash
# Get external IP or hostname
kubectl get svc istio-ingressgateway -n istio-system

# AWS EKS (hostname)
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# GCP/Azure (IP)
kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## Maintenance Tasks

### Drain and Cordon Nodes

```bash
# Cordon node (prevent new pods)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node
kubectl uncordon <node-name>
```

### Backup and Restore

```bash
# Backup with Velero
velero backup create my-backup --include-namespaces greenfield

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup my-backup

# Schedule daily backups
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces greenfield
```

### Clean Up Resources

```bash
# Delete deployment
kubectl delete deployment my-app -n greenfield

# Delete all resources with label
kubectl delete all -l app=my-app -n greenfield

# Delete namespace and all resources
kubectl delete namespace greenfield

# Clean failed pods
kubectl delete pods --field-selector status.phase=Failed -n greenfield
```

### Restart Pods

```bash
# Restart deployment (rolling restart)
kubectl rollout restart deployment/my-app -n greenfield

# Delete specific pod (it will be recreated)
kubectl delete pod <pod-name> -n greenfield

# Delete all pods with label
kubectl delete pods -l app=my-app -n greenfield
```

## Validation and Testing

### Validate Manifests

```bash
# Validate with dry-run
kubectl apply -f manifest.yaml --dry-run=client

# Build Kustomize
kustomize build kustomize/base/
kustomize build kustomize/overlays/prod/

# Lint Helm chart
helm lint helm/greenfield-cluster/

# Template Helm chart
helm template greenfield helm/greenfield-cluster/
```

### Test on Kind Cluster

```bash
# Create Kind cluster
make kind-create

# Deploy to Kind
kubectl apply -k kustomize/overlays/dev/

# Run tests
make test-kind-cluster

# Delete Kind cluster
make kind-delete
```

### Check Cluster Health

```bash
# Component status
kubectl get componentstatuses

# Cluster info
kubectl cluster-info

# Node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'

# Events
kubectl get events -n greenfield --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -n greenfield
```

## Batch Operations

### Update Multiple Resources

```bash
# Update all deployments with new image
kubectl set image deployment/* my-app=my-app:v2 -n greenfield

# Add label to all pods
kubectl label pods --all environment=production -n greenfield

# Add annotation to all services
kubectl annotate services --all prometheus.io/scrape=true -n greenfield
```

### Get Information from All Pods

```bash
# Get IP addresses of all pods
kubectl get pods -n greenfield -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Get container images
kubectl get pods -n greenfield -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Get resource requests
kubectl get pods -n greenfield -o json | jq '.items[] | {name: .metadata.name, requests: .spec.containers[].resources.requests}'
```

## Quick Troubleshooting

```bash
# One-liner to check common issues
echo "=== Nodes ===" && kubectl get nodes && \
echo "=== Pods ===" && kubectl get pods -n greenfield && \
echo "=== Events ===" && kubectl get events -n greenfield --sort-by='.lastTimestamp' | tail -10 && \
echo "=== Resources ===" && kubectl top nodes && kubectl top pods -n greenfield
```
