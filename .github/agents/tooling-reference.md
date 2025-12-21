# Tooling Reference Guide

Comprehensive reference for command-line tools used with the Greenfield Cluster.

## Quick Navigation

- [kubectl](#kubectl)
- [kustomize](#kustomize)
- [helm](#helm)
- [istioctl](#istioctl)
- [Cloud CLI Tools](#cloud-cli-tools)

---

## kubectl

The Kubernetes command-line tool for managing cluster resources.

### Installation

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# macOS
brew install kubectl

# Verify
kubectl version --client
```

### Common Commands

**Resource Management:**

```bash
# Get resources
kubectl get <resource>                    # List resources
kubectl get <resource> <name>             # Get specific resource
kubectl get <resource> -o wide            # Detailed output
kubectl get <resource> -o yaml            # YAML output
kubectl get <resource> -o json            # JSON output
kubectl get all                           # All resources in namespace

# Describe resources
kubectl describe <resource> <name>        # Detailed info with events
kubectl explain <resource>                # Show resource documentation

# Create/Update
kubectl apply -f <file>                   # Create or update from file
kubectl apply -k <directory>              # Apply Kustomize directory
kubectl create -f <file>                  # Create from file (fails if exists)
kubectl replace -f <file>                 # Replace existing resource

# Delete
kubectl delete <resource> <name>          # Delete specific resource
kubectl delete -f <file>                  # Delete from file
kubectl delete <resource> --all           # Delete all resources of type
```

**Namespace Operations:**

```bash
kubectl get namespaces                    # List namespaces
kubectl create namespace <name>           # Create namespace
kubectl delete namespace <name>           # Delete namespace
kubectl config set-context --current --namespace=<name>  # Set default namespace
```

**Pod Operations:**

```bash
kubectl get pods                          # List pods
kubectl get pods -n <namespace>           # List pods in namespace
kubectl logs <pod>                        # View logs
kubectl logs <pod> -f                     # Follow logs
kubectl logs <pod> --previous             # Logs from previous container
kubectl logs <pod> -c <container>         # Logs from specific container
kubectl exec -it <pod> -- <command>       # Execute command in pod
kubectl exec -it <pod> -- /bin/bash       # Interactive shell
kubectl cp <pod>:<path> <local-path>      # Copy from pod
kubectl cp <local-path> <pod>:<path>      # Copy to pod
kubectl port-forward <pod> <local>:<remote>  # Port forward
kubectl top pod <pod>                     # Resource usage
kubectl attach <pod>                      # Attach to running container
```

**Deployment Operations:**

```bash
kubectl create deployment <name> --image=<image>  # Create deployment
kubectl scale deployment <name> --replicas=<n>    # Scale deployment
kubectl rollout status deployment/<name>          # Check rollout status
kubectl rollout history deployment/<name>         # View rollout history
kubectl rollout undo deployment/<name>            # Rollback deployment
kubectl rollout restart deployment/<name>         # Restart deployment
kubectl set image deployment/<name> <container>=<image>  # Update image
kubectl autoscale deployment <name> --min=<n> --max=<n> --cpu-percent=<n>  # Autoscale
```

**Useful Flags:**

```bash
-n, --namespace <name>                    # Specify namespace
-A, --all-namespaces                      # All namespaces
-o wide                                   # Extended output
-o yaml                                   # YAML format
-o json                                   # JSON format
-l, --selector <key>=<value>              # Filter by label
--field-selector <key>=<value>            # Filter by field
-w, --watch                               # Watch for changes
--dry-run=client                          # Dry run (client-side)
--dry-run=server                          # Dry run (server-side)
```

**JSONPath Examples:**

```bash
# Get pod IPs
kubectl get pods -o jsonpath='{.items[*].status.podIP}'

# Get container images
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# Get pod names and IPs
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Get secret value
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d
```

### Context and Configuration

```bash
kubectl config view                       # View config
kubectl config get-contexts               # List contexts
kubectl config current-context            # Show current context
kubectl config use-context <context>      # Switch context
kubectl config set-context <context> --namespace=<namespace>  # Set namespace for context
```

### Debugging Commands

```bash
kubectl describe <resource> <name>        # Detailed info and events
kubectl get events                        # List events
kubectl get events --sort-by=.lastTimestamp  # Sorted events
kubectl top nodes                         # Node resource usage
kubectl top pods                          # Pod resource usage
kubectl auth can-i <verb> <resource>      # Check permissions
kubectl api-resources                     # List all resource types
kubectl api-versions                      # List API versions
```

---

## kustomize

Kubernetes configuration management using overlays and patches.

### Installation

```bash
# Install standalone
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/

# Or use kubectl (built-in)
kubectl apply -k <directory>

# Verify
kustomize version
```

### Common Commands

```bash
# Build configuration
kustomize build <directory>               # Output merged YAML
kustomize build <directory> > output.yaml # Save to file

# Create kustomization file
kustomize create --autodetect             # Auto-detect resources
kustomize create --resources deployment.yaml,service.yaml  # From specific files

# Edit kustomization
kustomize edit add resource <file>        # Add resource
kustomize edit add patch <file>           # Add patch
kustomize edit set namespace <namespace>  # Set namespace
kustomize edit set image <old>=<new>      # Set image
```

### Kustomization File Structure

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Base or other kustomizations
resources:
- ../base
- deployment.yaml
- service.yaml

# Namespace for all resources
namespace: greenfield

# Common labels for all resources
commonLabels:
  app: my-app
  environment: production

# Common annotations
commonAnnotations:
  managed-by: kustomize

# Name prefix/suffix
namePrefix: prod-
nameSuffix: -v1

# ConfigMap generator
configMapGenerator:
- name: my-config
  literals:
  - KEY=value
  files:
  - config.properties

# Secret generator
secretGenerator:
- name: my-secret
  literals:
  - password=secret

# Images
images:
- name: my-app
  newName: registry.io/my-app
  newTag: v2.0.0

# Patches
patchesStrategicMerge:
- patch-replicas.yaml

patchesJson6902:
- target:
    group: apps
    version: v1
    kind: Deployment
    name: my-app
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
```

### Using with kubectl

```bash
# Apply kustomization
kubectl apply -k <directory>

# View without applying
kubectl apply -k <directory> --dry-run=client -o yaml

# Delete kustomization
kubectl delete -k <directory>

# Diff
kubectl diff -k <directory>
```

---

## helm

Package manager for Kubernetes applications.

### Installation

```bash
# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# macOS
brew install helm

# Verify
helm version
```

### Common Commands

**Chart Management:**

```bash
# Create new chart
helm create <chart-name>

# Lint chart
helm lint <chart>

# Package chart
helm package <chart>

# Show chart values
helm show values <chart>

# Template chart (dry-run)
helm template <release> <chart>
helm template <release> <chart> -f values.yaml
helm template <release> <chart> --set key=value
```

**Repository Management:**

```bash
# Add repository
helm repo add <name> <url>
helm repo add stable https://charts.helm.sh/stable

# Update repositories
helm repo update

# List repositories
helm repo list

# Search charts
helm search repo <keyword>

# Remove repository
helm repo remove <name>
```

**Release Management:**

```bash
# Install chart
helm install <release> <chart>
helm install <release> <chart> -f values.yaml
helm install <release> <chart> --set key=value
helm install <release> <chart> --namespace <ns> --create-namespace

# Upgrade release
helm upgrade <release> <chart>
helm upgrade <release> <chart> -f values.yaml
helm upgrade --install <release> <chart>  # Install or upgrade

# List releases
helm list
helm list -A  # All namespaces
helm list -n <namespace>

# Get release info
helm get values <release>
helm get manifest <release>
helm get notes <release>

# Rollback release
helm rollback <release>
helm rollback <release> <revision>

# Uninstall release
helm uninstall <release>
helm uninstall <release> -n <namespace>

# History
helm history <release>
```

**Testing:**

```bash
# Test installation
helm test <release>

# Dry run
helm install <release> <chart> --dry-run --debug
```

### Chart Structure

```
my-chart/
├── Chart.yaml          # Chart metadata
├── values.yaml         # Default values
├── templates/          # Template files
│   ├── NOTES.txt       # Post-install notes
│   ├── _helpers.tpl    # Template helpers
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
└── charts/             # Dependencies
```

---

## istioctl

Command-line tool for Istio service mesh management.

### Installation

```bash
# Download and install
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Verify
istioctl version
```

### Common Commands

**Installation:**

```bash
# Install Istio
istioctl install --set profile=default -y
istioctl install --set profile=demo -y

# Verify installation
istioctl verify-install

# Uninstall Istio
istioctl uninstall --purge
```

**Configuration Analysis:**

```bash
# Analyze configuration
istioctl analyze
istioctl analyze -n <namespace>
istioctl analyze -A  # All namespaces

# Validate
istioctl validate -f <file>
```

**Proxy Management:**

```bash
# Proxy status
istioctl proxy-status
istioctl proxy-status <pod>

# Proxy configuration
istioctl proxy-config cluster <pod>
istioctl proxy-config listener <pod>
istioctl proxy-config route <pod>
istioctl proxy-config endpoint <pod>
istioctl proxy-config bootstrap <pod>

# Dashboard
istioctl dashboard controlz <pod>
istioctl dashboard envoy <pod>
istioctl dashboard kiali
istioctl dashboard prometheus
istioctl dashboard grafana
istioctl dashboard jaeger
```

**Security:**

```bash
# Check mTLS
istioctl authn tls-check <pod> <service>

# Create authorization policy
istioctl experimental authz check <pod>
```

**Debugging:**

```bash
# Bug report
istioctl bug-report

# Describe pod
istioctl experimental describe pod <pod>

# Logs
istioctl logs <pod>
```

**Injection:**

```bash
# Inject sidecar
istioctl kube-inject -f <file> | kubectl apply -f -

# Verify injection
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].name}'
```

---

## Cloud CLI Tools

### AWS CLI

**Installation:**

```bash
# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS
brew install awscli

# Configure
aws configure
```

**EKS Commands:**

```bash
# Update kubeconfig
aws eks update-kubeconfig --region <region> --name <cluster>

# List clusters
aws eks list-clusters

# Describe cluster
aws eks describe-cluster --name <cluster>

# Get nodegroup
aws eks list-nodegroups --cluster-name <cluster>
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup>
```

### Google Cloud SDK

**Installation:**

```bash
# Linux/macOS
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Initialize
gcloud init
```

**GKE Commands:**

```bash
# Get credentials
gcloud container clusters get-credentials <cluster> --region <region>

# List clusters
gcloud container clusters list

# Describe cluster
gcloud container clusters describe <cluster> --region <region>

# Resize cluster
gcloud container clusters resize <cluster> --num-nodes <n> --region <region>
```

### Azure CLI

**Installation:**

```bash
# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# macOS
brew install azure-cli

# Login
az login
```

**AKS Commands:**

```bash
# Get credentials
az aks get-credentials --resource-group <rg> --name <cluster>

# List clusters
az aks list

# Show cluster
az aks show --resource-group <rg> --name <cluster>

# Scale cluster
az aks scale --resource-group <rg> --name <cluster> --node-count <n>
```

---

## Additional Tools

### kubeseal (Sealed Secrets)

```bash
# Install
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/kubeseal-0.24.5-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.5-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Seal secret
kubeseal < secret.yaml > sealed-secret.yaml
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Get public key
kubeseal --fetch-cert > pub-cert.pem
```

### velero (Backup/Restore)

```bash
# Install
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz
tar -xvzf velero-v1.12.0-linux-amd64.tar.gz
sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/

# Create backup
velero backup create <name>

# Restore
velero restore create --from-backup <name>
```

### k9s (Terminal UI)

```bash
# Install
brew install k9s

# Run
k9s
k9s -n <namespace>
```

---

## Quick Reference

### kubectl Cheat Sheet

```bash
# Get commands with basic output
kubectl get services                # List all services
kubectl get pods --all-namespaces   # List all pods in all namespaces
kubectl get pods -o wide            # List pods with more info
kubectl get deployment my-dep       # Get a deployment

# Describe commands with verbose output
kubectl describe nodes my-node
kubectl describe pods my-pod

# Delete resources
kubectl delete -f ./pod.yaml
kubectl delete pod unwanted --now

# Execute a command on a pod
kubectl exec my-pod -- ls /
kubectl exec -it my-pod -- /bin/bash

# Logs
kubectl logs my-pod
kubectl logs -f my-pod
kubectl logs -p my-pod

# Debugging
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
```

For more detailed information, refer to each tool's official documentation.
