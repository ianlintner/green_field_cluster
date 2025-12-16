# Prerequisites

Before deploying Greenfield Cluster, ensure you have the following tools and resources.

## Required Tools

### kubectl

Kubernetes command-line tool for interacting with your cluster.

=== "Linux"
    ```bash
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    ```

=== "macOS"
    ```bash
    brew install kubectl
    ```

=== "Windows"
    ```powershell
    choco install kubernetes-cli
    ```

Verify installation:
```bash
kubectl version --client
```

### Kustomize

Kubernetes configuration management tool.

=== "Linux"
    ```bash
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
    ```

=== "macOS"
    ```bash
    brew install kustomize
    ```

=== "Built-in with kubectl"
    ```bash
    # kubectl has built-in kustomize support
    kubectl apply -k <directory>
    ```

### Helm (Optional)

Package manager for Kubernetes.

=== "Linux"
    ```bash
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ```

=== "macOS"
    ```bash
    brew install helm
    ```

=== "Windows"
    ```powershell
    choco install kubernetes-helm
    ```

Verify:
```bash
helm version
```

## Kubernetes Cluster

You need a running Kubernetes cluster. Options include:

### Local Development

#### Minikube

For local testing:

```bash
# Install Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable storage provisioner
minikube addons enable storage-provisioner
```

#### Kind

Kubernetes in Docker:

```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name greenfield
```

### Cloud Providers

=== "AWS EKS"
    ```bash
    # Install eksctl
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
    
    # Create cluster
    eksctl create cluster --name greenfield --region us-west-2
    ```

=== "GCP GKE"
    ```bash
    # Install gcloud
    curl https://sdk.cloud.google.com | bash
    
    # Create cluster
    gcloud container clusters create greenfield --zone us-central1-a
    ```

=== "Azure AKS"
    ```bash
    # Install Azure CLI
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    
    # Create cluster
    az aks create --resource-group greenfield-rg --name greenfield
    ```

## Cluster Requirements

### Minimum Resources

- **CPU**: 8 cores
- **Memory**: 16 GB RAM
- **Storage**: 50 GB available
- **Nodes**: 3 worker nodes (recommended)

### Kubernetes Version

- **Minimum**: v1.24
- **Recommended**: v1.28+

Check your cluster version:
```bash
kubectl version
```

### Storage Class

Ensure a default storage class is configured:

```bash
kubectl get storageclass
```

If no default exists, create one:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/gce-pd  # Adjust for your provider
parameters:
  type: pd-standard
```

## Additional Components

### Istio

Service mesh for traffic management and security.

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set profile=default -y

# Verify installation
kubectl get pods -n istio-system
```

### Sealed Secrets Controller

For encrypting Kubernetes secrets.

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml

# Install kubeseal CLI
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

## Docker (for building images)

Required if building the FastAPI example image.

=== "Linux"
    ```bash
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    ```

=== "macOS"
    ```bash
    brew install --cask docker
    ```

=== "Windows"
    Use Docker Desktop from docker.com

## Container Registry Access

If pushing images to a registry:

- Docker Hub account
- Cloud provider container registry (ECR, GCR, ACR)
- Private registry access

Configure authentication:
```bash
docker login your-registry.com
```

## Git

For version control:

```bash
# Check if installed
git --version

# Install if needed (Linux)
sudo apt-get install git
```

## Make (Optional but Recommended)

For using the provided Makefile:

```bash
# Linux
sudo apt-get install make

# macOS (included with Xcode Command Line Tools)
xcode-select --install
```

## Verification Checklist

Run this script to verify all prerequisites:

```bash
#!/bin/bash
echo "Checking prerequisites..."

check_command() {
    if command -v $1 &> /dev/null; then
        echo "✓ $1 is installed"
        $1 version 2>&1 | head -1
    else
        echo "✗ $1 is NOT installed"
    fi
}

check_command kubectl
check_command kustomize
check_command helm
check_command docker
check_command git
check_command make

echo ""
echo "Checking Kubernetes cluster..."
if kubectl cluster-info &> /dev/null; then
    echo "✓ Kubernetes cluster is accessible"
    kubectl version --short
else
    echo "✗ Cannot connect to Kubernetes cluster"
fi

echo ""
echo "Checking storage class..."
if kubectl get storageclass &> /dev/null; then
    echo "✓ Storage classes available:"
    kubectl get storageclass
else
    echo "✗ No storage classes found"
fi
```

Save as `check-prereqs.sh`, make executable, and run:
```bash
chmod +x check-prereqs.sh
./check-prereqs.sh
```

## Next Steps

Once prerequisites are installed:

1. [Quick Start Guide](quickstart.md) - Deploy the cluster
2. [Template Usage](template-usage.md) - Create your own project
3. [Deployment Methods](../deployment/methods.md) - Learn deployment options

## Troubleshooting

### Cannot connect to cluster

```bash
# Check kubectl config
kubectl config view

# Test connection
kubectl get nodes
```

### Storage class issues

```bash
# List storage classes
kubectl get sc

# Describe a storage class
kubectl describe sc <storage-class-name>
```

### Insufficient resources

For local development, ensure your cluster has enough resources:

```bash
# Minikube: Increase resources
minikube delete
minikube start --cpus=8 --memory=16384

# Kind: Increase worker nodes
kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```
