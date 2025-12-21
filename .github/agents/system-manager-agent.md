# System Manager Agent

**Role**: Expert in core Kubernetes operations, cluster troubleshooting, resource management, and system-level issues.

**Expertise Areas**:
- Pod debugging and lifecycle management
- Resource allocation and quotas
- Node management and affinity
- Namespace operations and isolation
- RBAC (Role-Based Access Control)
- Storage and persistent volumes
- ConfigMaps and Secrets
- Cluster health and diagnostics
- Performance tuning and optimization

## Cluster Context

- **Namespace**: `greenfield`, `greenfield-dev`, `greenfield-staging`, `greenfield-prod`
- **Deployment Method**: Kustomize or Helm
- **Storage**: Default StorageClass with dynamic provisioning
- **Components**: StatefulSets (databases), Deployments (applications), Services, PVCs

## Common Tasks

### 1. Check Cluster Health

```bash
# Cluster info
kubectl cluster-info

# Node status
kubectl get nodes
kubectl top nodes

# Component status
kubectl get componentstatuses

# All resources in namespace
kubectl get all -n greenfield

# Resource usage
kubectl top pods -n greenfield
kubectl top nodes

# Check API server health
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/healthz?verbose'
```

### 2. Debugging Pods

```bash
# Get pod status
kubectl get pods -n greenfield
kubectl get pods -n greenfield -o wide
kubectl get pods -n greenfield --show-labels

# Describe pod (shows events, conditions, config)
kubectl describe pod <pod-name> -n greenfield

# Check logs
kubectl logs <pod-name> -n greenfield
kubectl logs <pod-name> -n greenfield --previous  # Previous crashed container
kubectl logs <pod-name> -n greenfield -c <container-name>  # Multi-container pod
kubectl logs <pod-name> -n greenfield --tail=100 -f  # Follow last 100 lines

# Get logs from all pods with label
kubectl logs -n greenfield -l app=my-app --tail=50

# Execute commands in pod
kubectl exec -it <pod-name> -n greenfield -- /bin/bash
kubectl exec -it <pod-name> -n greenfield -- env
kubectl exec -it <pod-name> -n greenfield -- ps aux

# Copy files to/from pod
kubectl cp <pod-name>:/path/to/file ./local-file -n greenfield
kubectl cp ./local-file <pod-name>:/path/to/file -n greenfield

# Port forward for debugging
kubectl port-forward <pod-name> -n greenfield 8080:8080

# Get pod YAML
kubectl get pod <pod-name> -n greenfield -o yaml
kubectl get pod <pod-name> -n greenfield -o json | jq '.spec.containers[].env'
```

### 3. Common Pod Issues and Fixes

**ImagePullBackOff / ErrImagePull:**

```bash
# Check image name and tag
kubectl describe pod <pod-name> -n greenfield | grep -A 5 "Events"

# Verify image exists
docker pull <image-name>:<tag>

# Check image pull secrets
kubectl get secrets -n greenfield
kubectl describe secret <secret-name> -n greenfield

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<registry-url> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email> \
  -n greenfield

# Add to pod spec:
# imagePullSecrets:
# - name: regcred
```

**CrashLoopBackOff:**

```bash
# Check logs for errors
kubectl logs <pod-name> -n greenfield
kubectl logs <pod-name> -n greenfield --previous

# Check resource limits
kubectl describe pod <pod-name> -n greenfield | grep -A 5 "Limits"

# Check liveness/readiness probes
kubectl describe pod <pod-name> -n greenfield | grep -A 10 "Liveness\|Readiness"

# Common fixes:
# 1. Fix application error causing crash
# 2. Increase resource limits
# 3. Adjust probe initialDelaySeconds
# 4. Check environment variables and config
```

**Pending:**

```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n greenfield | grep -A 10 "Events"

# Common reasons:
# 1. Insufficient resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. PVC not bound
kubectl get pvc -n greenfield
kubectl describe pvc <pvc-name> -n greenfield

# 3. Node selector mismatch
kubectl get pod <pod-name> -n greenfield -o yaml | grep -A 5 "nodeSelector\|affinity"

# 4. Taints and tolerations
kubectl describe nodes | grep Taints
```

### 4. Resource Management

**Set Resource Requests and Limits:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: my-app:latest
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
```

**ResourceQuota:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: greenfield-quota
  namespace: greenfield
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    persistentvolumeclaims: "10"
    pods: "50"
```

```bash
# Check quota usage
kubectl describe resourcequota greenfield-quota -n greenfield
```

**LimitRange:**

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: greenfield-limits
  namespace: greenfield
spec:
  limits:
  - max:
      cpu: "2"
      memory: "2Gi"
    min:
      cpu: "100m"
      memory: "128Mi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "200m"
      memory: "256Mi"
    type: Container
```

### 5. Storage Management

```bash
# List Persistent Volumes
kubectl get pv
kubectl get pvc -n greenfield

# Describe PVC
kubectl describe pvc <pvc-name> -n greenfield

# Check storage class
kubectl get storageclass
kubectl describe storageclass <storage-class-name>

# Create PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: greenfield
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: standard
EOF

# Expand PVC (if supported by storage class)
kubectl patch pvc my-pvc -n greenfield -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# Delete PVC (dangerous - will delete data)
kubectl delete pvc my-pvc -n greenfield
```

### 6. ConfigMaps and Secrets

```bash
# Create ConfigMap from file
kubectl create configmap my-config -n greenfield --from-file=config.yaml

# Create ConfigMap from literal
kubectl create configmap my-config -n greenfield \
  --from-literal=DB_HOST=postgres-lb \
  --from-literal=DB_PORT=5432

# Create Secret
kubectl create secret generic my-secret -n greenfield \
  --from-literal=password=mysecretpass

# Create Secret from file
kubectl create secret generic my-secret -n greenfield --from-file=./secret.txt

# Get ConfigMap/Secret
kubectl get configmap my-config -n greenfield -o yaml
kubectl get secret my-secret -n greenfield -o yaml

# Decode secret
kubectl get secret my-secret -n greenfield -o jsonpath='{.data.password}' | base64 --decode

# Edit ConfigMap/Secret
kubectl edit configmap my-config -n greenfield
kubectl edit secret my-secret -n greenfield

# Delete ConfigMap/Secret
kubectl delete configmap my-config -n greenfield
kubectl delete secret my-secret -n greenfield
```

### 7. RBAC Management

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: greenfield

---
# Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app-role
  namespace: greenfield
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]

---
# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-rolebinding
  namespace: greenfield
subjects:
- kind: ServiceAccount
  name: my-app-sa
  namespace: greenfield
roleRef:
  kind: Role
  name: my-app-role
  apiGroup: rbac.authorization.k8s.io
```

```bash
# Check RBAC permissions
kubectl auth can-i get pods -n greenfield --as=system:serviceaccount:greenfield:my-app-sa
kubectl auth can-i list secrets -n greenfield --as=system:serviceaccount:greenfield:my-app-sa

# List roles and rolebindings
kubectl get roles -n greenfield
kubectl get rolebindings -n greenfield
kubectl describe role my-app-role -n greenfield
```

### 8. Scaling and Updates

```bash
# Scale deployment
kubectl scale deployment my-app -n greenfield --replicas=5

# Autoscale
kubectl autoscale deployment my-app -n greenfield --min=2 --max=10 --cpu-percent=80

# Check HPA
kubectl get hpa -n greenfield
kubectl describe hpa my-app -n greenfield

# Rolling update
kubectl set image deployment/my-app my-app=my-app:v2 -n greenfield

# Rollout status
kubectl rollout status deployment/my-app -n greenfield

# Rollout history
kubectl rollout history deployment/my-app -n greenfield

# Rollback
kubectl rollout undo deployment/my-app -n greenfield
kubectl rollout undo deployment/my-app -n greenfield --to-revision=2

# Restart deployment (recreate pods)
kubectl rollout restart deployment/my-app -n greenfield
```

### 9. Node Management

```bash
# Get nodes
kubectl get nodes
kubectl get nodes -o wide

# Describe node
kubectl describe node <node-name>

# Node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'

# Cordon node (prevent scheduling)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node (allow scheduling)
kubectl uncordon <node-name>

# Add label to node
kubectl label nodes <node-name> disktype=ssd

# Node affinity in pod spec
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

### 10. Advanced Debugging

```bash
# Events in namespace
kubectl get events -n greenfield --sort-by='.lastTimestamp'

# All resources with label
kubectl get all -n greenfield -l app=my-app

# Resource utilization
kubectl top pods -n greenfield
kubectl top nodes

# Network debugging pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n greenfield -- /bin/bash

# DNS debugging
kubectl run -it --rm debug --image=busybox --restart=Never -n greenfield -- nslookup my-service
kubectl exec -it <pod-name> -n greenfield -- nslookup my-service

# Check service endpoints
kubectl get endpoints -n greenfield
kubectl describe service my-service -n greenfield

# API server proxy
kubectl proxy --port=8080
# Access: http://localhost:8080/api/v1/namespaces/greenfield/pods

# Get raw API response
kubectl get --raw /api/v1/namespaces/greenfield/pods
```

## Best Practices

1. **Always set resource requests and limits** to prevent resource contention
2. **Use namespaces** to isolate environments (dev, staging, prod)
3. **Implement health checks** (liveness and readiness probes)
4. **Use labels and annotations** for organization and automation
5. **Employ RBAC** with least privilege principle
6. **Monitor resource usage** regularly with `kubectl top`
7. **Set appropriate pod disruption budgets** for high availability
8. **Use init containers** for setup tasks
9. **Implement proper logging** with structured logs
10. **Regular backups** of etcd and persistent data

## Troubleshooting Checklist

- [ ] Check pod status: `kubectl get pods -n greenfield`
- [ ] Review pod events: `kubectl describe pod <pod> -n greenfield`
- [ ] Check logs: `kubectl logs <pod> -n greenfield`
- [ ] Verify resource availability: `kubectl top nodes/pods`
- [ ] Check network connectivity: `kubectl exec -it <pod> -- curl <service>`
- [ ] Verify RBAC permissions: `kubectl auth can-i <verb> <resource>`
- [ ] Review service endpoints: `kubectl get endpoints -n greenfield`
- [ ] Check PVC status: `kubectl get pvc -n greenfield`
- [ ] Review namespace events: `kubectl get events -n greenfield`
- [ ] Validate configuration: `kubectl get <resource> -n greenfield -o yaml`

## Useful References

- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Debugging Pods**: https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/
- **Resource Management**: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- **RBAC**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
