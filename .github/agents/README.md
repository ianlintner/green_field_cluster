# AI Agent Instructions for Greenfield Cluster

This directory contains specialized AI agent instructions for working with the Greenfield Cluster. Each agent has deep domain expertise and provides guidance, commands, and best practices for specific aspects of cluster management and operations.

## Available Agents

### 🌐 [Networking & Service Mesh Agent](./networking-agent.md)
Expert in Istio service mesh, ingress/egress gateways, traffic management, mTLS, and network policies.

**Use for:** Setting up ingress, configuring SSL/TLS, traffic routing, circuit breakers, retries, timeouts, and Istio troubleshooting.

### 📊 [Observability Agent](./observability-agent.md)
Expert in monitoring, tracing, metrics, and logging with Prometheus, Grafana, Jaeger, OpenTelemetry, and Kiali.

**Use for:** Setting up dashboards, configuring alerts, troubleshooting performance issues, distributed tracing, and metrics collection.

### 🔧 [System Manager Agent](./system-manager-agent.md)
Expert in core Kubernetes operations, cluster troubleshooting, resource management, and system-level issues.

**Use for:** Debugging pod issues, resource allocation, node management, namespace operations, RBAC, and general cluster health.

### 💾 [Database & Data Manager Agent](./database-agent.md)
Expert in managing Redis, PostgreSQL, MySQL, MongoDB, Kafka, and data persistence in Kubernetes.

**Use for:** Database deployment, scaling, backup/restore, connection pooling, replication setup, and data migration.

### 🚀 [Application Setup Agent](./application-agent.md)
Expert in deploying applications, configuring microservices, setting up CI/CD, and application-level concerns.

**Use for:** Deploying new apps, configuring environment variables, setting up health checks, integrating with observability, and application troubleshooting.

### 🔐 [Security Agent](./security-agent.md)
Expert in Kubernetes security, secrets management, authentication, authorization, network policies, and compliance.

**Use for:** Configuring authentication, managing secrets with Sealed Secrets, setting up RBAC, implementing network policies, and security hardening.

### ☁️ [Infrastructure & Platform Agent](./infrastructure-agent.md)
Expert in cloud providers (AWS, GCP, Azure), infrastructure provisioning, storage configuration, and platform-specific features.

**Use for:** Setting up EKS/GKE/AKS clusters, configuring cloud storage, load balancers, DNS, and cloud-native services integration.

## Quick Reference

### [Common Tasks](./common-tasks.md)
Frequently performed operations with ready-to-use commands and code examples.

### [Tooling Reference](./tooling-reference.md)
Comprehensive guide to kubectl, helm, kustomize, istioctl, and cloud CLI tools.

### [Quick Reference Cards](./quick-reference/)
One-page cheat sheets for each domain area.

## How to Use These Instructions

1. **Choose the right agent** based on your task domain
2. **Read the agent's overview** to understand their expertise
3. **Follow the provided patterns and examples** for consistency
4. **Use the common tasks** for quick copy-paste solutions
5. **Refer to tooling reference** for command syntax

## Cluster Context

This Greenfield Cluster includes:

- **Infrastructure**: Redis, PostgreSQL, MySQL, MongoDB, Kafka
- **Service Mesh**: Istio with mTLS, traffic management
- **Observability**: Prometheus, Grafana, Jaeger, OpenTelemetry, Kiali
- **Security**: cert-manager, Sealed Secrets, modular authentication
- **Deployment**: Kustomize and Helm support with dev/staging/prod overlays
- **Example Apps**: FastAPI application with full instrumentation

See [PROJECT_SUMMARY.md](../../PROJECT_SUMMARY.md) for complete details.

## Best Practices

1. **Always validate manifests** before applying: `kubectl apply --dry-run=client -f manifest.yaml`
2. **Use namespaces** to isolate environments: dev, staging, prod
3. **Follow existing patterns** in `kustomize/base/` for consistency
4. **Test in dev first** before deploying to production
5. **Check logs and events** when troubleshooting: `kubectl logs`, `kubectl describe`
6. **Use labels and annotations** consistently for better observability
7. **Document changes** in commit messages and PR descriptions

## Getting Help

- **General Documentation**: [docs-mkdocs/](../../docs-mkdocs/)
- **Quick Start**: [Getting Started Guide](../../docs-mkdocs/docs/getting-started/quickstart.md)
- **Architecture**: [Architecture Overview](../../docs-mkdocs/docs/components/architecture.md)
- **Security**: [Security Guide](../../docs-mkdocs/docs/security/overview.md)

## Contributing

When adding new agent instructions:
1. Follow the existing format and structure
2. Include practical, tested examples
3. Add links to official documentation
4. Keep language clear and actionable
5. Update this README with the new agent
