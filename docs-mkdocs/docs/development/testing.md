# Testing

## CI Testing with Kind

The project includes automated testing on a local Kubernetes cluster using [Kind (Kubernetes in Docker)](https://kind.sigs.k8s.io/). This provides a more realistic testing environment during CI runs.

### What Gets Tested

The CI pipeline automatically:

1. **Creates a Kind cluster** - A lightweight, local Kubernetes cluster
2. **Deploys manifests** - Applies the Kustomize base manifests to the cluster
3. **Validates deployment** - Checks that resources are created successfully
4. **Reports status** - Shows pod status and any issues encountered

### Testing Locally

You can test the manifests on your local machine using the same process as CI:

#### Prerequisites

Install the required tools:

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl (if not already installed)
# See: https://kubernetes.io/docs/tasks/tools/

# Install kustomize (if not already installed)
# See: https://kubectl.docs.kubernetes.io/installation/kustomize/
```

#### Run the Test Script

Use the provided test script to create a Kind cluster and deploy manifests:

```bash
# Run the automated test script
./scripts/test-kind-cluster.sh

# Or use Make targets
make test-kind-cluster
```

#### Manual Testing

For more control, use the individual Make targets:

```bash
# Create a Kind cluster
make kind-create

# Build and apply manifests manually
kustomize build kustomize/base/ > /tmp/manifests.yaml
kubectl apply -f kustomize/base/namespace/
kubectl apply -f /tmp/manifests.yaml

# Check status
kubectl get pods -n greenfield
kubectl get all -n greenfield

# Clean up
make kind-delete
```

### Environment Variables

Customize the test script behavior:

```bash
# Use a custom cluster name
KIND_CLUSTER_NAME=my-test ./scripts/test-kind-cluster.sh

# Use a different namespace
NAMESPACE=my-namespace ./scripts/test-kind-cluster.sh

# Manually create and test
kind create cluster --name my-test --config scripts/kind-config.yaml
MANIFEST_FILE=$(mktemp)
kustomize build kustomize/base/ > "${MANIFEST_FILE}"
kubectl apply -f "${MANIFEST_FILE}"
rm -f "${MANIFEST_FILE}"
```

### Troubleshooting

#### Some resources fail to deploy

This is expected! Resources that depend on CRDs (Custom Resource Definitions) from Istio, cert-manager, or other controllers will fail. The test focuses on validating that the base manifests are syntactically correct and can be processed by Kubernetes.

#### Pods are in Pending state

This is normal in a basic Kind cluster. Many services require persistent volumes or specific node configurations that aren't available in the minimal test cluster. The CI test validates that manifests can be applied, not that all services reach a Ready state.

#### Clean up after testing

```bash
# Delete the Kind cluster
make kind-delete

# Or manually
kind delete cluster --name greenfield-test
```

## CI Workflow

The complete CI pipeline includes:

1. **Kustomize Validation** - Ensures base and overlays build correctly
2. **Helm Validation** - Lints and templates Helm charts
3. **YAML Validation** - Checks YAML syntax and formatting
4. **Kubeconform** - Validates Kubernetes resource schemas
5. **Kind Cluster Test** - Deploys to a real Kubernetes cluster (new!)

All tests must pass before code can be merged.

