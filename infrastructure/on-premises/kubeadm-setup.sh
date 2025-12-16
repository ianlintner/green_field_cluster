#!/bin/bash
# Kubernetes Cluster Setup Script using kubeadm
# Supports Ubuntu 20.04+ and similar Debian-based distributions

set -e

KUBE_VERSION="1.28.0-00"
POD_CIDR="10.244.0.0/16"

print_usage() {
    echo "Usage: $0 {init|control-plane|worker} [args]"
    echo ""
    echo "Commands:"
    echo "  init                          - Install prerequisites on all nodes"
    echo "  control-plane                 - Initialize control plane node"
    echo "  worker <cp-ip> <token> <hash> - Join worker node to cluster"
    echo ""
    echo "Example:"
    echo "  sudo $0 init"
    echo "  sudo $0 control-plane"
    echo "  sudo $0 worker 192.168.1.10 abcdef.1234567890abcdef sha256:hash..."
}

install_prerequisites() {
    echo "==> Installing prerequisites..."
    
    # Disable swap
    echo "Disabling swap..."
    swapoff -a
    sed -i '/ swap / s/^/#/' /etc/fstab
    
    # Load kernel modules
    echo "Loading kernel modules..."
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    modprobe overlay
    modprobe br_netfilter
    
    # Set sysctl parameters
    echo "Setting sysctl parameters..."
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sysctl --system
    
    # Install containerd
    echo "Installing containerd..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg containerd
    
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    
    # Configure containerd to use systemd cgroup driver
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    systemctl restart containerd
    systemctl enable containerd
    
    # Install Kubernetes components
    echo "Installing Kubernetes components..."
    apt-get install -y apt-transport-https
    
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
    
    apt-get update
    apt-get install -y kubelet=$KUBE_VERSION kubeadm=$KUBE_VERSION kubectl=$KUBE_VERSION
    apt-mark hold kubelet kubeadm kubectl
    
    echo "==> Prerequisites installed successfully!"
}

init_control_plane() {
    echo "==> Initializing control plane..."
    
    kubeadm init --pod-network-cidr=$POD_CIDR
    
    # Setup kubeconfig for root
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    
    # Setup kubeconfig for sudo user if different from root
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        SUDO_HOME=$(eval echo ~$SUDO_USER)
        mkdir -p $SUDO_HOME/.kube
        cp -f /etc/kubernetes/admin.conf $SUDO_HOME/.kube/config
        chown -R $SUDO_USER:$SUDO_USER $SUDO_HOME/.kube
    fi
    
    echo "==> Installing Calico CNI..."
    kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
    
    echo ""
    echo "==> Control plane initialized successfully!"
    echo ""
    echo "To join worker nodes, use the command shown above that looks like:"
    echo "  kubeadm join <ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    echo ""
    echo "Or run this script on worker nodes:"
    echo "  sudo $0 worker <control-plane-ip> <token> <hash>"
}

join_worker() {
    if [ $# -ne 3 ]; then
        echo "Error: worker command requires 3 arguments"
        print_usage
        exit 1
    fi
    
    CP_IP=$1
    TOKEN=$2
    HASH=$3
    
    echo "==> Joining worker node to cluster..."
    kubeadm join ${CP_IP}:6443 --token $TOKEN --discovery-token-ca-cert-hash sha256:$HASH
    
    echo "==> Worker node joined successfully!"
}

# Main script
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

case "$1" in
    init)
        install_prerequisites
        ;;
    control-plane)
        init_control_plane
        ;;
    worker)
        shift
        join_worker "$@"
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
