# Sealed Secrets Installation Guide

Sealed Secrets is a Kubernetes controller and tool for one-way encrypted Secrets.

## Installation

### Using Helm:

```bash
# Add sealed-secrets Helm repository
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

# Install sealed-secrets controller
helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set-string fullnameOverride=sealed-secrets-controller
```

### Using kubectl:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
```

## Install kubeseal CLI

### Linux:

```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### macOS:

```bash
brew install kubeseal
```

## Usage

### Create a sealed secret from a secret:

```bash
# Create a regular Kubernetes secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass \
  --dry-run=client \
  -o yaml > secret.yaml

# Seal the secret
kubeseal -f secret.yaml -w sealed-secret.yaml \
  --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller

# Apply the sealed secret
kubectl apply -f sealed-secret.yaml -n greenfield
```

### Create a sealed secret directly:

```bash
echo -n mypassword | kubectl create secret generic my-sealed-secret \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -o yaml | \
kubeseal -o yaml > my-sealed-secret.yaml
```

## Verification

```bash
# Check sealed-secrets controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check if secret was created from sealed secret
kubectl get secrets -n greenfield
```

## Example Sealed Secrets

The `examples/` directory contains sample sealed secrets for:
- PostgreSQL passwords
- MySQL passwords
- MongoDB passwords
- Grafana admin password

To use them in your environment, you need to:
1. Create regular secrets with your actual values
2. Use `kubeseal` to encrypt them
3. Replace the example sealed secrets with your encrypted versions
