# Greenfield Cluster - GitHub Copilot Instructions

You are assisting with the **Greenfield Cluster** project, a production-ready Kubernetes cluster template for greenfield projects and startups.

## Repository Context

This is a **GitHub template repository** designed to be cloned/forked for new projects. Users will:

1. Create a new repository from this template
2. Customize it for their specific needs
3. Deploy to their Kubernetes cluster
4. Use GitHub Copilot to assist with customization

## Project Structure

```
green_field_cluster/
├── kustomize/          # Kubernetes manifests with Kustomize
│   ├── base/           # Base configurations for all components
│   └── overlays/       # Environment-specific configs (dev/staging/prod)
├── helm/               # Helm chart alternative
├── apps/               # Example applications
└── docs-mkdocs/        # MkDocs documentation
```

## Core Components

The cluster includes these pre-configured components:

### Infrastructure
- **Redis**: Master-replica caching (1 master + 2 replicas)
- **PostgreSQL**: 3-node cluster for relational data
- **MySQL**: 3-node cluster (alternative RDBMS)
- **MongoDB**: 3-node replica set for documents
- **Kafka**: 3-broker cluster with Zookeeper for messaging
- **Istio**: Service mesh with mTLS and traffic management

### Observability
- **OpenTelemetry Collector**: Centralized telemetry collection
- **Jaeger**: Distributed tracing with UI
- **Prometheus**: Metrics collection with service discovery
- **Grafana**: Dashboards with pre-configured data sources
- **SLO Framework**: Cluster and application SLO metrics with recording rules
- **Alerting**: Environment-aware alerts based on SLO violations
- **AlertManager**: Optional intelligent alert routing and grouping

### Example Application
- **FastAPI**: Fully instrumented example with OTel, Prometheus metrics, and database connectivity

## Common User Scenarios

### Scenario 1: Creating a New Project from Template

When a user says: *"I just created a repo from this template, help me set it up"*

Provide guidance on:
1. Updating project name and namespace
2. Reviewing which components they need
3. Removing unnecessary components
4. Configuring secrets properly
5. Deploying to their cluster

### Scenario 2: Customizing Components

When a user says: *"I only need PostgreSQL and Redis, remove the rest"*

Help them:
1. Edit `kustomize/base/kustomization.yaml` to remove unwanted components
2. Update `helm/greenfield-cluster/values.yaml` to disable services
3. Validate the changes with `make validate`
4. Test deployment

### Scenario 3: Adding New Services

When a user says: *"Add a Node.js API service that connects to PostgreSQL"*

Help them:
1. Create manifests in `kustomize/base/my-service/`
2. Follow the pattern of `fastapi-app` for consistency
3. Include proper resource limits, health checks, and observability
4. Connect to existing infrastructure (PostgreSQL, OTel)
5. Add to base kustomization

### Scenario 4: Scaling for Production

When a user says: *"I need to scale this for production with 10 API replicas"*

Help them:
1. Edit `kustomize/overlays/prod/kustomization.yaml`
2. Adjust replica counts
3. Update resource limits
4. Configure persistent storage sizes
5. Review security settings

### Scenario 5: Setting Up SLOs and Alerting

When a user says: *"I want to set up monitoring SLOs and alerts for my production cluster"*

Help them:
1. Review the default SLOs in `kustomize/base/observability/`
2. Enable AlertManager by uncommenting it in `kustomize/base/observability/kustomization.yaml`
3. Configure notification channels in `alertmanager/configmap.yaml` (Slack, PagerDuty, email)
4. Adjust alert thresholds for their environment in the alert ConfigMaps
5. Set up environment-specific routing in overlay patches
6. Point them to the comprehensive documentation at `docs-mkdocs/docs/observability/`

Key points:
- SLOs are pre-configured for cluster health (API server, nodes, resources) and application performance (error rate, latency, saturation)
- Alerting is environment-aware: strict for production, relaxed for dev/staging
- Low-traffic environments automatically suppress false positives
- Grafana dashboards are included for SLO visualization

## Code Generation Guidelines

### When Creating Kubernetes Manifests

Always include:
- Resource requests and limits
- Liveness and readiness probes
- Proper labels and annotations
- Namespace reference: `greenfield`
- OpenTelemetry environment variables for applications
- Prometheus scraping annotations if applicable

Example deployment pattern:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-service
  namespace: greenfield
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-service
  template:
    metadata:
      labels:
        app: my-service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: my-service
          image: my-service:latest
          ports:
            - containerPort: 8080
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4317"
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
```

### When Creating Application Code

If helping with application code:
- Use OpenTelemetry for tracing
- Include Prometheus metrics endpoint
- Use environment variables for configuration
- Include health check endpoints
- Connect to databases using service names (e.g., `postgres-lb`, `redis-master`)

### When Modifying Kustomize

Follow these patterns:
- Base contains complete, working configurations
- Overlays patch or extend base for environments
- Use `kustomization.yaml` files consistently
- Validate with `kustomize build` after changes

### When Working with Helm

- Update `values.yaml` for configuration changes
- Keep templates in sync with kustomize base when possible
- Use `helm lint` and `helm template` to validate

## Security Reminders

Always remind users to:
- Change default passwords (marked with warnings)
- Use Sealed Secrets for production
- Enable Istio mTLS
- Configure RBAC properly
- Scan images for vulnerabilities

## Common Commands

Suggest these commands when relevant:

```bash
# Validation
make validate                    # Validate all manifests
kustomize build kustomize/base/  # Build base config

# Deployment
kubectl apply -k kustomize/overlays/dev/   # Deploy dev
helm install greenfield helm/greenfield-cluster/  # Deploy with Helm

# Testing
kubectl get pods -n greenfield   # Check pod status
kubectl logs -f <pod-name> -n greenfield  # View logs
```

## Template-Specific Patterns

### Naming Conventions
- Namespace: `greenfield` (users may change)
- Service names: `{component}-{role}` (e.g., `postgres-lb`, `redis-master`)
- Labels: `app: {component}`

### Environment Variables for Apps
Standard environment variables to use:
- `OTEL_EXPORTER_OTLP_ENDPOINT`: `http://otel-collector:4317`
- `POSTGRES_HOST`: `postgres-lb`
- `REDIS_HOST`: `redis-master`
- `MYSQL_HOST`: `mysql-lb`
- `MONGODB_HOST`: `mongodb-lb`
- `KAFKA_BROKERS`: `kafka-lb:9092`

### Storage Patterns
- StatefulSets use volumeClaimTemplates
- Default storage: 1-5Gi per component
- Production: Scale up in overlays

## Documentation References

Point users to:
- Quick Start: `docs-mkdocs/docs/getting-started/quickstart.md`
- Template Usage: `docs-mkdocs/docs/getting-started/template-usage.md`
- Architecture: `docs-mkdocs/docs/components/architecture.md`
- Security: `docs-mkdocs/docs/security/overview.md`

## Troubleshooting Hints

Common issues and solutions:
- **Pods pending**: Check PVC status and storage class
- **ImagePullBackOff**: Build and tag images properly
- **CrashLoopBackOff**: Check logs and environment variables
- **Connection refused**: Verify service names and namespaces

## Key Reminders

1. This is a **template** - users will customize it for their projects
2. Keep components **modular** - easy to add/remove
3. Follow **existing patterns** for consistency
4. Prioritize **production-readiness** (security, observability, scaling)
5. Be **helpful but concise** - users want to move fast

## Example Interactions

**User**: "I need to add authentication to my API"

**Response**: "I can help you add authentication. Here are the recommended approaches:

1. **OAuth2/OIDC** with an identity provider (Keycloak, Auth0)
2. **JWT tokens** with your own service
3. **Istio RequestAuthentication** for service mesh-level auth

Which approach fits your needs? I can help you implement it."

**User**: "Remove MongoDB and MySQL, I only need PostgreSQL"

**Response**: "I'll help you remove MongoDB and MySQL. Here's what we need to do:

1. Edit `kustomize/base/kustomization.yaml` and comment out:
   ```yaml
   # - mysql
   # - mongodb
   ```

2. For Helm users, edit `helm/greenfield-cluster/values.yaml`:
   ```yaml
   mysql:
     enabled: false
   mongodb:
     enabled: false
   ```

3. Validate: `make validate`

Would you like me to show you the exact changes?"

## Response Style

- **Be proactive**: Anticipate follow-up questions
- **Be specific**: Provide exact file paths and code
- **Be educational**: Explain why, not just how
- **Be template-aware**: Remember this is for customization
- **Validate suggestions**: Reference existing patterns in the repo
