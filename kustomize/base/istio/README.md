# Istio Installation Guide

This directory contains the configuration for Istio service mesh.

## Installation

Istio should be installed separately using the Istio operator or Helm chart before applying the application manifests.

### Using Istio Operator:

```bash
# Install Istio operator
kubectl apply -f https://github.com/istio/istio/releases/download/1.20.0/istio-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=600s deployment/istio-operator -n istio-operator

# Install Istio control plane
kubectl apply -f istio-config.yaml
```

### Using Helm:

```bash
# Add Istio Helm repository
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install Istio base
helm install istio-base istio/base -n istio-system --create-namespace

# Install Istiod
helm install istiod istio/istiod -n istio-system --wait

# Install Istio ingress gateway
helm install istio-ingress istio/gateway -n istio-system
```

## Verification

```bash
# Check Istio installation
kubectl get pods -n istio-system

# Verify namespace injection
kubectl get namespace greenfield -o yaml | grep istio-injection
```
