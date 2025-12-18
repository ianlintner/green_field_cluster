# Scripts

This directory contains utility scripts for the Greenfield Cluster project.

## kind-config.yaml

Kind cluster configuration file used by:
- `test-kind-cluster.sh` script
- `Makefile` targets
- GitHub Actions CI workflow

This shared configuration ensures consistency across all testing environments.

## test-kind-cluster.sh

Tests Kubernetes manifests on a local Kind (Kubernetes in Docker) cluster.

### Usage

```bash
# Basic usage
./scripts/test-kind-cluster.sh

# With custom cluster name
KIND_CLUSTER_NAME=my-test ./scripts/test-kind-cluster.sh

# With custom namespace
NAMESPACE=my-namespace ./scripts/test-kind-cluster.sh
```

### What it does

1. Checks that required tools are installed (kind, kubectl, kustomize)
2. Creates a Kind cluster using `kind-config.yaml` (if it doesn't exist)
3. Builds manifests using Kustomize (with secure temporary files)
4. Applies manifests to the cluster
5. Shows deployment status and pod information

### Prerequisites

- [Kind](https://kind.sigs.k8s.io/) - Kubernetes in Docker
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) - Kubernetes manifest customization

### Environment Variables

- `KIND_CLUSTER_NAME` - Name of the Kind cluster (default: `greenfield-test`)
- `NAMESPACE` - Kubernetes namespace to use (default: `greenfield`)

### Notes

- Some resources may fail to apply if they depend on CRDs (e.g., Istio, cert-manager)
- This is expected and doesn't indicate a problem with the manifests
- The script validates that manifests are syntactically correct and can be processed by Kubernetes
- Uses `mktemp` for secure temporary file handling
