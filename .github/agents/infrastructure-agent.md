# Infrastructure & Platform Agent

**Role**: Expert in cloud providers (AWS, GCP, Azure), infrastructure provisioning, storage configuration, and platform-specific features.

**Expertise Areas**:
- AWS EKS cluster management
- Google GKE operations
- Azure AKS configuration
- Cloud storage classes and persistent volumes
- Load balancer and ingress configuration
- DNS and domain management
- Cloud IAM and service accounts
- Infrastructure as Code (Terraform, CloudFormation)

## Cluster Context

The Greenfield Cluster supports deployment on:
- **AWS EKS**: Elastic Kubernetes Service
- **GCP GKE**: Google Kubernetes Engine
- **Azure AKS**: Azure Kubernetes Service
- **DigitalOcean**: Kubernetes
- **On-premises**: kubeadm, k3s, RKE2

Infrastructure examples available in `infrastructure/` directory.

## Common Tasks

### 1. AWS EKS Cluster Setup

**Using Terraform:**

```bash
cd infrastructure/aws

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Create EKS cluster
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name greenfield-cluster

# Verify connection
kubectl get nodes
```

**Terraform Configuration (example):**

```hcl
# main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "greenfield-cluster"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 2
      max_size     = 5

      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "production"
    Project     = "greenfield"
  }
}
```

**EKS Storage Class:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**EKS Load Balancer:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
  namespace: greenfield
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

### 2. GCP GKE Cluster Setup

**Using Terraform:**

```bash
cd infrastructure/gcp

# Authenticate
gcloud auth application-default login

# Initialize Terraform
terraform init

# Create GKE cluster
terraform apply

# Configure kubectl
gcloud container clusters get-credentials greenfield-cluster --region us-central1

# Verify
kubectl get nodes
```

**Terraform Configuration:**

```hcl
# main.tf
resource "google_container_cluster" "primary" {
  name     = "greenfield-cluster"
  location = "us-central1"
  
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
```

**GKE Storage Class:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
  replication-type: regional-pd
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**GKE Load Balancer:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
  namespace: greenfield
  annotations:
    cloud.google.com/load-balancer-type: "External"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

### 3. Azure AKS Cluster Setup

**Using Terraform:**

```bash
cd infrastructure/azure

# Login to Azure
az login

# Initialize Terraform
terraform init

# Create AKS cluster
terraform apply

# Configure kubectl
az aks get-credentials --resource-group greenfield-rg --name greenfield-cluster

# Verify
kubectl get nodes
```

**Terraform Configuration:**

```hcl
# main.tf
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "greenfield-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "greenfield"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }
}
```

**AKS Storage Class:**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azure-disk-premium
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

**AKS Load Balancer:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
  namespace: greenfield
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "false"
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```

### 4. Configure Cloud Storage

**Dynamic Volume Provisioning:**

```yaml
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-volume
  namespace: greenfield
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3  # AWS: gp3, GCP: pd-ssd, Azure: azure-disk-premium
  resources:
    requests:
      storage: 10Gi
```

**StatefulSet with Volume Claims:**

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-stateful-app
  namespace: greenfield
spec:
  serviceName: my-app
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: my-app:v1
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: gp3
      resources:
        requests:
          storage: 5Gi
```

### 5. DNS Configuration

**AWS Route53:**

```bash
# Get load balancer hostname
LB_HOSTNAME=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route53 record (using AWS CLI)
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$LB_HOSTNAME'"}]
      }
    }]
  }'
```

**GCP Cloud DNS:**

```bash
# Get load balancer IP
LB_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create DNS record
gcloud dns record-sets create myapp.example.com \
  --zone=my-zone \
  --type=A \
  --ttl=300 \
  --rrdatas=$LB_IP
```

**Azure DNS:**

```bash
# Get load balancer IP
LB_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create DNS record
az network dns record-set a add-record \
  --resource-group greenfield-rg \
  --zone-name example.com \
  --record-set-name myapp \
  --ipv4-address $LB_IP
```

### 6. Cloud IAM and Service Accounts

**AWS IRSA (IAM Roles for Service Accounts):**

```bash
# Create IAM role with trust policy for EKS
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/CLUSTER_ID:sub": "system:serviceaccount:greenfield:my-app-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role --role-name my-app-role --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy --role-name my-app-role --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Annotate service account
kubectl annotate serviceaccount my-app-sa \
  -n greenfield \
  eks.amazonaws.com/role-arn=arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

**GCP Workload Identity:**

```bash
# Create GCP service account
gcloud iam service-accounts create my-app-sa

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member "serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role "roles/storage.objectViewer"

# Bind Kubernetes SA to GCP SA
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[greenfield/my-app-sa]"

# Annotate Kubernetes service account
kubectl annotate serviceaccount my-app-sa \
  -n greenfield \
  iam.gke.io/gcp-service-account=my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

**Azure Managed Identity:**

```bash
# Create managed identity
az identity create --resource-group greenfield-rg --name my-app-identity

# Assign role to identity
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee $(az identity show --resource-group greenfield-rg --name my-app-identity --query principalId -o tsv) \
  --scope /subscriptions/SUBSCRIPTION_ID/resourceGroups/greenfield-rg

# Enable pod identity on AKS (if not already enabled)
az aks pod-identity add \
  --resource-group greenfield-rg \
  --cluster-name greenfield-cluster \
  --namespace greenfield \
  --name my-app-identity \
  --identity-resource-id $(az identity show --resource-group greenfield-rg --name my-app-identity --query id -o tsv)
```

### 7. Cluster Autoscaling

**AWS Cluster Autoscaler:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.27.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/greenfield-cluster
```

**GKE Autoscaling (enabled by default):**

```bash
# Enable autoscaling on node pool
gcloud container clusters update greenfield-cluster \
  --enable-autoscaling \
  --min-nodes 2 \
  --max-nodes 10 \
  --zone us-central1-a
```

**AKS Autoscaling:**

```bash
# Enable cluster autoscaler
az aks update \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --enable-cluster-autoscaler \
  --min-count 2 \
  --max-count 10
```

### 8. Backup and Disaster Recovery

**Velero Backup:**

```bash
# Install Velero (AWS example)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket greenfield-backups \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file ./credentials-velero

# Create backup
velero backup create greenfield-backup --include-namespaces greenfield

# Schedule daily backups
velero schedule create daily-backup --schedule="0 2 * * *" --include-namespaces greenfield

# Restore from backup
velero restore create --from-backup greenfield-backup
```

### 9. Monitoring Cloud Resources

**AWS CloudWatch:**

```bash
# Enable CloudWatch Container Insights
aws eks update-cluster-config \
  --name greenfield-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}'

# Install CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

**GCP Operations (formerly Stackdriver):**

```bash
# Already integrated by default with GKE
# View metrics in Google Cloud Console
gcloud container clusters describe greenfield-cluster --format="value(loggingService,monitoringService)"
```

**Azure Monitor:**

```bash
# Enable Azure Monitor for containers
az aks enable-addons \
  --resource-group greenfield-rg \
  --name greenfield-cluster \
  --addons monitoring
```

### 10. Cost Optimization

**Check Resource Usage:**

```bash
# Get node costs (AWS)
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name) \(.status.allocatable.cpu) \(.status.allocatable.memory)"'

# View resource requests vs usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check for over-provisioned resources
kubectl get pods --all-namespaces -o json | jq '.items[] | {name: .metadata.name, requests: .spec.containers[].resources.requests, limits: .spec.containers[].resources.limits}'
```

**Spot/Preemptible Instances:**

```hcl
# AWS Spot instances in Terraform
eks_managed_node_groups = {
  spot = {
    desired_size = 2
    min_size     = 1
    max_size     = 5
    
    instance_types = ["t3.large", "t3a.large"]
    capacity_type  = "SPOT"
  }
}
```

## Best Practices

1. **Use Infrastructure as Code** (Terraform, CloudFormation) for reproducibility
2. **Enable cluster autoscaling** for cost optimization
3. **Use managed node groups** when available
4. **Implement backup strategy** with Velero or cloud-native solutions
5. **Enable audit logging** at the cloud provider level
6. **Use cloud-native storage classes** for better integration
7. **Leverage cloud IAM** for pod-level permissions
8. **Monitor cloud costs** regularly
9. **Use spot/preemptible instances** for non-critical workloads
10. **Implement multi-AZ/multi-region** for high availability

## Troubleshooting Checklist

- [ ] Check cluster status: `kubectl cluster-info`
- [ ] Verify node status: `kubectl get nodes`
- [ ] Check cloud provider quotas and limits
- [ ] Review cloud provider console for infrastructure issues
- [ ] Verify IAM roles and permissions
- [ ] Check security groups/firewall rules
- [ ] Review load balancer configuration
- [ ] Verify DNS records are correct
- [ ] Check storage class availability
- [ ] Review cloud provider audit logs

## Useful References

- **AWS EKS**: https://docs.aws.amazon.com/eks/
- **GCP GKE**: https://cloud.google.com/kubernetes-engine/docs
- **Azure AKS**: https://docs.microsoft.com/en-us/azure/aks/
- **Terraform Kubernetes Providers**: https://registry.terraform.io/browse/providers?category=kubernetes
- **Velero**: https://velero.io/docs/
