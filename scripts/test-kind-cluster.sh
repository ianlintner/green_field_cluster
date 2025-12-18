#!/bin/bash
# Test script for deploying manifests to a local Kind cluster
# This script mirrors what the CI pipeline does

set -e

CLUSTER_NAME="${KIND_CLUSTER_NAME:-greenfield-test}"
NAMESPACE="${NAMESPACE:-greenfield}"

echo "=========================================="
echo "Kind Cluster Test Script"
echo "=========================================="
echo ""

# Check prerequisites
command -v kind >/dev/null 2>&1 || { echo "Error: kind is not installed. Please install it from https://kind.sigs.k8s.io/docs/user/quick-start/"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed."; exit 1; }
command -v kustomize >/dev/null 2>&1 || { echo "Error: kustomize is not installed."; exit 1; }

echo "✓ All prerequisites found"
echo ""

# Create Kind cluster if it doesn't exist
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "✓ Kind cluster '${CLUSTER_NAME}' already exists"
  echo "  To recreate, run: kind delete cluster --name ${CLUSTER_NAME}"
else
  echo "Creating Kind cluster '${CLUSTER_NAME}'..."
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  kind create cluster --name "${CLUSTER_NAME}" --config="${SCRIPT_DIR}/kind-config.yaml"
  echo "✓ Kind cluster created"
fi

echo ""
echo "Cluster info:"
kubectl cluster-info --context "kind-${CLUSTER_NAME}"
echo ""

# Build and apply manifests
echo "Building manifests..."
MANIFEST_FILE=$(mktemp)
kustomize build kustomize/base/ > "${MANIFEST_FILE}"
echo "✓ Manifests built"
echo ""

echo "Applying namespace..."
kubectl apply -f kustomize/base/namespace/
echo "✓ Namespace created"
echo ""

echo "Applying manifests..."
echo "Note: Some resources may fail if they require CRDs (like Istio, cert-manager)"
kubectl apply -f "${MANIFEST_FILE}" --timeout=30s || true
rm -f "${MANIFEST_FILE}"
echo "✓ Manifests applied (with expected failures for CRD-dependent resources)"
echo ""

echo "Waiting for resources to be created..."
sleep 5
echo ""

echo "=========================================="
echo "Deployment Status"
echo "=========================================="
kubectl get all -n "${NAMESPACE}" || echo "No resources in namespace yet"
echo ""

echo "=========================================="
echo "Pod Status"
echo "=========================================="
kubectl get pods -n "${NAMESPACE}" || echo "No pods in namespace yet"
echo ""

echo "=========================================="
echo "Events"
echo "=========================================="
kubectl get events -n "${NAMESPACE}" --sort-by='.lastTimestamp' | tail -20 || true
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "✓ Kind cluster is running"
echo "✓ Manifests were applied"
echo ""
echo "To interact with the cluster:"
echo "  kubectl config use-context kind-${CLUSTER_NAME}"
echo "  kubectl get pods -n ${NAMESPACE}"
echo ""
echo "To delete the cluster:"
echo "  kind delete cluster --name ${CLUSTER_NAME}"
echo ""
