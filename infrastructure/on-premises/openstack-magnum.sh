#!/bin/bash
# OpenStack Magnum Kubernetes Cluster Setup Script

set -e

CLUSTER_NAME="greenfield-cluster"
TEMPLATE_NAME="greenfield-template"
MASTER_FLAVOR="m1.medium"
WORKER_FLAVOR="m1.large"
MASTER_COUNT=1
WORKER_COUNT=3
IMAGE_NAME="fedora-coreos"
NETWORK_DRIVER="calico"
EXTERNAL_NETWORK="public"
DNS_NAMESERVER="8.8.8.8"
DOCKER_VOLUME_SIZE=20

print_usage() {
    echo "Usage: $0 {create-template|create-cluster|get-config|delete-cluster|delete-template}"
    echo ""
    echo "Commands:"
    echo "  create-template  - Create cluster template"
    echo "  create-cluster   - Create Kubernetes cluster"
    echo "  get-config       - Download kubeconfig"
    echo "  delete-cluster   - Delete the cluster"
    echo "  delete-template  - Delete the template"
    echo ""
    echo "Prerequisites:"
    echo "  - OpenStack CLI installed"
    echo "  - OpenStack credentials configured"
    echo "  - Magnum service available"
}

check_prerequisites() {
    if ! command -v openstack &> /dev/null; then
        echo "Error: OpenStack CLI not found. Please install python-openstackclient."
        exit 1
    fi
    
    if ! openstack coe service list &> /dev/null; then
        echo "Error: Magnum service not available in your OpenStack cloud."
        exit 1
    fi
}

create_template() {
    echo "==> Creating cluster template: $TEMPLATE_NAME"
    
    openstack coe cluster template create $TEMPLATE_NAME \
        --image $IMAGE_NAME \
        --external-network $EXTERNAL_NETWORK \
        --dns-nameserver $DNS_NAMESERVER \
        --master-flavor $MASTER_FLAVOR \
        --flavor $WORKER_FLAVOR \
        --docker-volume-size $DOCKER_VOLUME_SIZE \
        --network-driver $NETWORK_DRIVER \
        --volume-driver cinder \
        --coe kubernetes \
        --labels kube_tag=v1.28.0
    
    echo "==> Template created successfully!"
    openstack coe cluster template show $TEMPLATE_NAME
}

create_cluster() {
    echo "==> Creating Kubernetes cluster: $CLUSTER_NAME"
    
    openstack coe cluster create $CLUSTER_NAME \
        --cluster-template $TEMPLATE_NAME \
        --master-count $MASTER_COUNT \
        --node-count $WORKER_COUNT \
        --timeout 60
    
    echo ""
    echo "==> Cluster creation initiated!"
    echo "This will take approximately 10-15 minutes."
    echo ""
    echo "Monitor progress with:"
    echo "  openstack coe cluster show $CLUSTER_NAME"
    echo ""
    echo "Once status is CREATE_COMPLETE, run:"
    echo "  $0 get-config"
}

get_config() {
    echo "==> Checking cluster status..."
    
    STATUS=$(openstack coe cluster show $CLUSTER_NAME -f value -c status)
    
    if [ "$STATUS" != "CREATE_COMPLETE" ]; then
        echo "Cluster status: $STATUS"
        echo "Cluster is not ready yet. Please wait until status is CREATE_COMPLETE."
        exit 1
    fi
    
    echo "==> Downloading kubeconfig..."
    
    openstack coe cluster config $CLUSTER_NAME
    
    echo ""
    echo "==> Kubeconfig saved!"
    echo "Export the config:"
    echo "  export KUBECONFIG=./config"
    echo ""
    echo "Verify cluster:"
    echo "  kubectl get nodes"
}

delete_cluster() {
    echo "==> Deleting cluster: $CLUSTER_NAME"
    
    read -p "Are you sure you want to delete the cluster? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deletion cancelled."
        exit 0
    fi
    
    openstack coe cluster delete $CLUSTER_NAME
    
    echo "==> Cluster deletion initiated!"
    echo "Monitor progress with:"
    echo "  openstack coe cluster list"
}

delete_template() {
    echo "==> Deleting template: $TEMPLATE_NAME"
    
    read -p "Are you sure you want to delete the template? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deletion cancelled."
        exit 0
    fi
    
    openstack coe cluster template delete $TEMPLATE_NAME
    
    echo "==> Template deleted!"
}

# Main script
check_prerequisites

case "$1" in
    create-template)
        create_template
        ;;
    create-cluster)
        create_cluster
        ;;
    get-config)
        get_config
        ;;
    delete-cluster)
        delete_cluster
        ;;
    delete-template)
        delete_template
        ;;
    *)
        print_usage
        exit 1
        ;;
esac
