# Kubectl Quick Reference Card

## Essential Commands

### Get Resources
```bash
kubectl get pods                    # List pods
kubectl get pods -n <namespace>     # Pods in namespace
kubectl get pods -o wide            # Extended info
kubectl get all                     # All resources
kubectl get all -A                  # All resources, all namespaces
```

### Describe & Debug
```bash
kubectl describe pod <pod>          # Pod details + events
kubectl logs <pod>                  # View logs
kubectl logs <pod> -f               # Follow logs
kubectl exec -it <pod> -- /bin/bash # Shell into pod
kubectl top pods                    # Resource usage
```

### Apply & Create
```bash
kubectl apply -f <file>             # Create/update from file
kubectl apply -k <dir>              # Apply kustomize
kubectl create -f <file>            # Create only
kubectl delete -f <file>            # Delete from file
```

### Deployments
```bash
kubectl scale deploy <name> --replicas=3        # Scale
kubectl rollout status deploy/<name>            # Check status
kubectl rollout restart deploy/<name>           # Restart
kubectl rollout undo deploy/<name>              # Rollback
kubectl set image deploy/<name> app=image:v2    # Update image
```

### Namespace
```bash
kubectl get ns                      # List namespaces
kubectl create ns <name>            # Create namespace
kubectl config set-context --current --namespace=<name>  # Set default
```

### Port Forward
```bash
kubectl port-forward <pod> 8080:8080             # Pod
kubectl port-forward svc/<service> 8080:80       # Service
```

### Context
```bash
kubectl config get-contexts         # List contexts
kubectl config use-context <ctx>    # Switch context
kubectl config current-context      # Show current
```

### Useful Aliases
```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kx='kubectl exec -it'
```

## Common Patterns

### Debug Pod
```bash
kubectl run debug --image=busybox --rm -it -- sh
kubectl run debug --image=nicolaka/netshoot --rm -it -- bash
```

### Get All Pod IPs
```bash
kubectl get pods -o wide
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'
```

### Check Events
```bash
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -n <namespace> --watch
```

### Resource Usage
```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods --sort-by=cpu
kubectl top pods --sort-by=memory
```

### Test Connectivity
```bash
kubectl exec -it <pod> -- curl http://service:port
kubectl exec -it <pod> -- nslookup service
kubectl exec -it <pod> -- ping service
```

---

# Greenfield Cluster Quick Reference

## Namespaces
- `greenfield` - Production
- `greenfield-dev` - Development
- `greenfield-staging` - Staging
- `istio-system` - Istio components

## Services

### Databases
- `postgres-lb:5432` - PostgreSQL
- `redis-master:6379` - Redis
- `mysql-lb:3306` - MySQL
- `mongodb-lb:27017` - MongoDB
- `kafka-lb:9092` - Kafka

### Observability
- `prometheus:9090` - Metrics
- `grafana:3000` - Dashboards
- `jaeger-query:16686` - Traces
- `kiali:20001` - Service Mesh UI
- `otel-collector:4317` - OTLP gRPC
- `otel-collector:4318` - OTLP HTTP

## Access Services

```bash
# Prometheus
kubectl port-forward -n greenfield svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n greenfield svc/grafana 3000:3000

# Jaeger
kubectl port-forward -n greenfield svc/jaeger-query 16686:16686

# Kiali
kubectl port-forward -n greenfield svc/kiali 20001:20001
```

## Deploy

```bash
# Dev
kubectl apply -k kustomize/overlays/dev/

# Prod
kubectl apply -k kustomize/overlays/prod/

# Helm
helm install greenfield helm/greenfield-cluster -n greenfield --create-namespace
```

## Makefile Commands

```bash
make validate               # Validate manifests
make deploy-dev            # Deploy dev environment
make deploy-prod           # Deploy production
make test-kind-cluster     # Test on local Kind cluster
make port-forward          # Setup port forwarding
make auth.install          # Install authentication
make auth.protect          # Protect an application
```

## Environment Variables

Applications should use these service names:
- `POSTGRES_HOST=postgres-lb`
- `REDIS_HOST=redis-master`
- `MYSQL_HOST=mysql-lb`
- `MONGODB_HOST=mongodb-lb`
- `KAFKA_BROKERS=kafka-lb:9092`
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`

## Common Issues

**Pod Pending**: Check PVC status and resource availability
**ImagePullBackOff**: Verify image name and registry access
**CrashLoopBackOff**: Check logs and environment variables
**Connection Refused**: Verify service name and port

## Quick Health Check

```bash
kubectl get nodes
kubectl get pods -n greenfield
kubectl get svc -n greenfield
kubectl get events -n greenfield --sort-by='.lastTimestamp' | tail -10
kubectl top nodes
kubectl top pods -n greenfield
```
