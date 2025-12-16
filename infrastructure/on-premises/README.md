# On-Premises Kubernetes Setup

This directory contains examples and scripts for setting up Kubernetes clusters on-premises or with OpenStack.

## Overview

For on-premises deployments, you have several options:

1. **kubeadm** - Official Kubernetes cluster bootstrapping tool
2. **k3s** - Lightweight Kubernetes distribution
3. **RKE2** - Rancher Kubernetes Engine
4. **OpenStack Magnum** - Kubernetes on OpenStack

## Option 1: kubeadm (Recommended for traditional deployments)

### Prerequisites

- Ubuntu 20.04+ or RHEL 8+ servers
- Minimum 2 CPU, 4GB RAM per node
- 3+ nodes recommended (1 control plane, 2+ workers)
- Network connectivity between nodes
- Root or sudo access

### Quick Start Script

See `kubeadm-setup.sh` for a complete installation script.

```bash
# On each node
sudo ./kubeadm-setup.sh init

# On control plane node
sudo ./kubeadm-setup.sh control-plane

# On worker nodes (use token from control plane output)
sudo ./kubeadm-setup.sh worker <control-plane-ip> <token> <discovery-token-ca-cert-hash>
```

### Manual Setup

1. **Prepare All Nodes**

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install containerd
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Install kubeadm, kubelet, kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

2. **Initialize Control Plane**

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

3. **Join Worker Nodes**

```bash
# On worker nodes, use the join command from kubeadm init output
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

## Option 2: k3s (Lightweight, recommended for edge/resource-constrained)

### Quick Start

```bash
# On control plane node
curl -sfL https://get.k3s.io | sh -

# Get node token
sudo cat /var/lib/rancher/k3s/server/node-token

# On worker nodes
curl -sfL https://get.k3s.io | K3S_URL=https://<control-plane-ip>:6443 K3S_TOKEN=<token> sh -

# Setup kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
# Edit the config to replace 127.0.0.1 with your control plane IP
```

### Features
- Single binary installation
- Built-in containerd
- Automatic certificate management
- Small footprint (< 512MB RAM)
- Perfect for ARM devices (Raspberry Pi, etc.)

## Option 3: RKE2 (Enterprise-grade)

### Quick Start

```bash
# On control plane node
curl -sfL https://get.rke2.io | sh -
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

# Get node token
sudo cat /var/lib/rancher/rke2/server/node-token

# Setup kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# On worker nodes
curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -
sudo mkdir -p /etc/rancher/rke2
echo "server: https://<control-plane-ip>:9345" | sudo tee /etc/rancher/rke2/config.yaml
echo "token: <token>" | sudo tee -a /etc/rancher/rke2/config.yaml
sudo systemctl enable rke2-agent.service
sudo systemctl start rke2-agent.service
```

## Option 4: OpenStack with Magnum

For OpenStack environments, you can use Magnum to deploy Kubernetes clusters.

See `openstack-magnum.sh` for example commands.

### Prerequisites
- OpenStack cloud with Magnum enabled
- OpenStack CLI installed and configured

### Quick Start

```bash
# Create cluster template
openstack coe cluster template create greenfield-template \
  --image fedora-coreos \
  --external-network public \
  --dns-nameserver 8.8.8.8 \
  --master-flavor m1.medium \
  --flavor m1.large \
  --docker-volume-size 20 \
  --network-driver calico \
  --coe kubernetes

# Create cluster
openstack coe cluster create greenfield-cluster \
  --cluster-template greenfield-template \
  --master-count 1 \
  --node-count 3

# Wait for creation (can take 10-15 minutes)
openstack coe cluster show greenfield-cluster

# Get kubeconfig
openstack coe cluster config greenfield-cluster
```

## Deploy Greenfield Cluster

Once your Kubernetes cluster is ready:

```bash
# Verify cluster
kubectl get nodes

# Deploy Greenfield
cd ../..
kubectl apply -k kustomize/overlays/dev/

# Or use Helm
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## Hardware Recommendations

### Minimal (Development/Testing)
- **Control Plane**: 2 vCPU, 4GB RAM, 50GB disk
- **Workers**: 2x (2 vCPU, 4GB RAM, 50GB disk)
- **Total**: 3 nodes, 6 vCPU, 12GB RAM

### Production
- **Control Plane**: 3x (4 vCPU, 8GB RAM, 100GB disk) - HA setup
- **Workers**: 3+ (4 vCPU, 8GB RAM, 100GB disk)
- **Total**: 6+ nodes, 24+ vCPU, 48+ GB RAM

### ARM Support

All options (kubeadm, k3s, RKE2) work well on ARM64:
- Raspberry Pi 4 (4GB+ RAM)
- Ampere Altra servers
- AWS Graviton instances
- Other ARM64 servers

## Storage Considerations

For persistent storage, you'll need a storage solution:

1. **Local Path Provisioner** (Development)
```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
```

2. **NFS** (Simple shared storage)
```bash
# Install NFS client on all nodes
sudo apt-get install -y nfs-common

# Use NFS provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<nfs-server-ip> \
  --set nfs.path=/exported/path
```

3. **Longhorn** (Cloud-native storage)
```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
```

4. **Ceph/Rook** (Enterprise-grade, distributed storage)

## Network Considerations

### CNI Options
- **Calico**: Full-featured, good performance
- **Flannel**: Simple, easy to setup
- **Cilium**: eBPF-based, advanced features
- **Weave**: Easy setup, encryption

### Load Balancer

For on-premises, you'll need a load balancer solution:

1. **MetalLB** (Recommended)
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

Configure IP address pool:
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
```

2. **HAProxy/Nginx** (External load balancer)

## Security Considerations

1. **Firewall Rules**: Configure firewall between nodes
2. **Network Segmentation**: Separate control plane and data plane
3. **RBAC**: Enable and configure Kubernetes RBAC
4. **Secrets**: Use Sealed Secrets or external secret manager
5. **Updates**: Regular security updates for OS and Kubernetes

## Monitoring & Maintenance

1. **Node Updates**: Plan for rolling updates
2. **Backup**: Regular etcd backups for control plane
3. **Monitoring**: Deploy Prometheus/Grafana (included in Greenfield)
4. **Logging**: Consider EFK or Loki stack

## Troubleshooting

### Nodes Not Ready
```bash
kubectl get nodes
kubectl describe node <node-name>
journalctl -u kubelet -f
```

### Pod Networking Issues
```bash
kubectl get pods -A
kubectl logs -n kube-system <cni-pod>
```

### Certificate Issues
```bash
kubeadm certs check-expiration
kubeadm certs renew all
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/setup/)
- [kubeadm Guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [k3s Documentation](https://docs.k3s.io/)
- [RKE2 Documentation](https://docs.rke2.io/)
- [OpenStack Magnum](https://docs.openstack.org/magnum/latest/)
