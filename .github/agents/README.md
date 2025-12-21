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
One-page cheat sheets such as the kubectl cheatsheet, with additional domain-specific cards to be added over time.

## How to Use These Instructions

1. **Choose the right agent** based on your task domain
2. **Read the agent's overview** to understand their expertise
3. **Follow the provided patterns and examples** for consistency
4. **Use the common tasks** for quick copy-paste solutions
5. **Refer to tooling reference** for command syntax

## Recommended AI Models

These instructions are designed to work with advanced AI models capable of understanding complex technical documentation and executing multi-step operations. Recommended model classes as of December 2025:

### Optimal Performance (Recommended)
- **Anthropic Claude 3.5 Sonnet (or latest in Claude 3.x family)** - Excellent for complex Kubernetes operations, infrastructure as code, and debugging
- **OpenAI GPT-4 Turbo (or latest GPT-4 series)** - Strong general-purpose capabilities for cluster management tasks
- **Google Gemini Pro 1.5+ (or latest Gemini Pro)** - Good for multi-cloud scenarios with large context windows

### Good Performance
- **Anthropic Claude 3 Opus** - Reliable for detailed troubleshooting and security tasks
- **OpenAI GPT-4** - Solid choice for most cluster operations
- **Google Gemini Pro** - Capable for standard deployment and management tasks

### Model Selection Guidelines

**For Complex Tasks** (multi-step deployments, architecture decisions, troubleshooting):
- Use Claude 3.5 Sonnet or GPT-4 Turbo for best results
- These models handle the detailed context in agent instructions effectively

**For Standard Operations** (deployments, config changes, monitoring setup):
- GPT-4 or Gemini Pro 1.5 work well
- Faster response times with good accuracy

**For Quick Reference Tasks** (command lookup, syntax help):
- Any of the recommended models will suffice
- Consider using models with faster response times

### Context Window Considerations

These agent instructions contain ~125KB of documentation. For best results:
- **Minimum recommended**: 32K token context window
- **Optimal**: 128K+ token context window (allows full context of multiple agents)
- **Large operations**: Use Claude 3.5 Sonnet or Gemini Pro 1.5+ with their extended context capabilities

### Note on Model Evolution

AI models evolve rapidly. When using these instructions:
- Always use the **latest version** in the recommended model class
- Newer models in the same family (e.g., Claude 4.x, GPT-5.x) will generally perform better
- Test with your specific use cases to determine the best model for your needs

## Recommended MCP Servers

Model Context Protocol (MCP) servers enhance AI agents with specialized capabilities. These MCPs are particularly useful for VS Code and Copilot-compatible coding agents working with Kubernetes clusters.

### Essential MCPs for Cluster Operations

**File System & Code Access**
- **@modelcontextprotocol/server-filesystem** - Access repository files, read configurations, and analyze manifests
  - Essential for reading and modifying Kubernetes YAML files
  - Navigate the `kustomize/` and `helm/` directories

**Command Execution**
- **@modelcontextprotocol/server-bash** - Execute kubectl, helm, kustomize, and other CLI commands
  - Run diagnostic commands: `kubectl get pods`, `kubectl describe`
  - Execute deployment commands: `kubectl apply -k`, `helm install`
  - Query cluster state and resources

**GitHub Integration**
- **@modelcontextprotocol/server-github** - Interact with repository, PRs, issues, and GitHub Actions
  - Review CI/CD workflow runs
  - Check deployment status in GitHub Actions
  - Manage issues and pull requests

### Recommended MCPs for Enhanced Functionality

**Database Operations**
- **@modelcontextprotocol/server-postgres** - Direct PostgreSQL database access for debugging and queries
- **@modelcontextprotocol/server-sqlite** - Local database operations for testing

**Cloud Provider MCPs**
- **AWS MCP Server** - Interact with AWS services (EKS, ECR, S3, CloudWatch)
  - Query EKS cluster status
  - Check CloudWatch logs and metrics
  - Manage ECR container images
- **Google Cloud MCP** - GCP operations (GKE, GCR, Cloud Storage)
- **Azure MCP** - Azure services (AKS, ACR, Azure Monitor)

**Web & API Access**
- **@modelcontextprotocol/server-fetch** - Fetch documentation, API endpoints, and external resources
  - Query Kubernetes API server directly
  - Access Prometheus/Grafana APIs for metrics
  - Fetch external documentation

**Search & Documentation**
- **@modelcontextprotocol/server-brave-search** - Search for solutions, documentation, and troubleshooting guides
- **@modelcontextprotocol/server-exa** - Semantic search for technical documentation

### MCP Configuration Example

For VS Code with Copilot, configure MCPs in your settings:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/home/runner/work/green_field_cluster/green_field_cluster"]
    },
    "bash": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-bash"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### MCP Usage Guidelines

**For Kubernetes Operations:**
1. Use **filesystem MCP** to read manifests and configurations
2. Use **bash MCP** to execute kubectl commands and debug cluster issues
3. Use **github MCP** to review CI/CD workflows and deployment status

**For Cloud Operations:**
4. Use **cloud provider MCPs** (AWS/GCP/Azure) for cluster provisioning and management
5. Use **fetch MCP** to query monitoring APIs (Prometheus, Grafana, Jaeger)

**For Documentation & Troubleshooting:**
6. Use **search MCPs** to find solutions for errors and issues
7. Combine multiple MCPs for complex operations (e.g., filesystem + bash + github)

### Security Considerations

When using MCPs:
- **Limit file system access** to repository directories only
- **Use read-only tokens** for GitHub MCP when possible
- **Rotate credentials** for cloud provider MCPs regularly
- **Review MCP permissions** before granting access
- **Use environment variables** for sensitive credentials (never hardcode)

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
