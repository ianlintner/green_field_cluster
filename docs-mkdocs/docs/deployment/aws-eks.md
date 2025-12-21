# AWS EKS Deployment

This guide covers deploying Greenfield Cluster on Amazon EKS (Elastic Kubernetes Service) with ARM Graviton instances for optimal price/performance.

## Overview

Amazon EKS provides managed Kubernetes clusters on AWS, offering:

- **Managed Control Plane**: AWS handles the Kubernetes control plane
- **ARM Graviton Support**: 15-20% cost savings with ARM instances
- **AWS Integration**: Native integration with AWS services (EBS, ELB, IAM)
- **High Availability**: Multi-AZ control plane and worker nodes
- **Auto-scaling**: Cluster autoscaler and horizontal pod autoscaling

## Prerequisites

- AWS account with appropriate permissions
- [AWS CLI](https://aws.amazon.com/cli/) v2.x configured
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0 (for IaC deployment)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) v1.24+
- [eksctl](https://eksctl.io/) (optional, for manual setup)

## Deployment Options

### Option 1: Terraform (Recommended)

Use our Terraform configuration for automated, reproducible deployments.

#### Quick Start

```bash
# Navigate to AWS infrastructure directory
cd infrastructure/aws/

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Create cluster (takes 10-15 minutes)
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name greenfield-cluster

# Verify cluster
kubectl get nodes
```

#### Custom Configuration

Create `terraform.tfvars`:

```hcl
cluster_name     = "my-greenfield-cluster"
aws_region       = "us-west-2"
environment      = "dev"
use_arm          = true              # Use ARM Graviton instances
node_desired     = 3
node_min         = 2
node_max         = 6
arm_instance_types = ["t4g.large"]  # 2 vCPU, 8GB RAM
```

Apply configuration:

```bash
terraform apply
```

See the complete [AWS Infrastructure Guide](../../../infrastructure/aws/README.md) for all configuration options.

### Option 2: eksctl

Use eksctl for quick cluster creation without Terraform.

#### Basic Cluster

```bash
eksctl create cluster \
  --name greenfield-cluster \
  --region us-west-2 \
  --node-type t4g.large \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 6 \
  --managed
```

#### Advanced Cluster with ARM

Create `cluster-config.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: greenfield-cluster
  region: us-west-2
  version: "1.28"

managedNodeGroups:
  - name: greenfield-arm-nodes
    instanceType: t4g.large
    desiredCapacity: 3
    minSize: 2
    maxSize: 6
    volumeSize: 50
    volumeType: gp3
    privateNetworking: true
    labels:
      role: worker
      arch: arm64
    tags:
      Environment: production
      Project: greenfield
    iam:
      withAddonPolicies:
        ebs: true
        efs: true
        albIngress: true
        cloudWatch: true

addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
  - name: aws-ebs-csi-driver
```

Deploy:

```bash
eksctl create cluster -f cluster-config.yaml
```

### Option 3: AWS Console

Manual creation through AWS Console:

1. **Navigate to EKS**: AWS Console → EKS → Clusters
2. **Create Cluster**: Click "Create cluster"
3. **Configure**:
   - Name: greenfield-cluster
   - Kubernetes version: 1.28
   - Cluster service role: Create or select role
4. **Networking**: Select VPC, subnets (multi-AZ)
5. **Add-ons**: Enable CoreDNS, kube-proxy, VPC CNI
6. **Create**: Wait 10-15 minutes
7. **Add Node Group**:
   - Name: greenfield-nodes
   - Instance type: t4g.large
   - Desired: 3, Min: 2, Max: 6
   - Disk size: 50 GB

## Architecture

### Default Configuration

| Component | Configuration |
|-----------|---------------|
| **Region** | us-west-2 (configurable) |
| **K8s Version** | 1.28 |
| **Control Plane** | Managed by AWS (Multi-AZ) |
| **Worker Nodes** | t4g.large ARM Graviton |
| **Node Count** | 2-6 (3 desired, auto-scaling) |
| **Node Storage** | 50 GB gp3 EBS |
| **Networking** | VPC with public/private subnets |
| **CNI** | AWS VPC CNI |

### ARM vs x86 Instance Options

#### ARM (Graviton) - Default

**Advantages:**
- 15-20% cost savings
- Better performance per dollar
- Lower energy consumption

**Instance Types:**
- `t4g.large`: 2 vCPU, 8 GB RAM (~$0.0672/hr)
- `t4g.xlarge`: 4 vCPU, 16 GB RAM (~$0.1344/hr)
- `t4g.2xlarge`: 8 vCPU, 32 GB RAM (~$0.2688/hr)

#### x86 - Fallback

**Instance Types:**
- `t3.large`: 2 vCPU, 8 GB RAM (~$0.0832/hr)
- `t3.xlarge`: 4 vCPU, 16 GB RAM (~$0.1664/hr)
- `t3.2xlarge`: 8 vCPU, 32 GB RAM (~$0.3328/hr)

**When to use x86:**
- Legacy applications without ARM support
- Specific software requiring x86 architecture

### Network Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Region                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │                  VPC 10.0.0.0/16                │    │
│  │                                                 │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────┼────┐
│  │  │  AZ 1        │  │  AZ 2        │  │  AZ 3  │    │
│  │  │              │  │              │  │        │    │
│  │  │ Public       │  │ Public       │  │ Public │    │
│  │  │ Subnet       │  │ Subnet       │  │ Subnet │    │
│  │  │              │  │              │  │        │    │
│  │  │ Private      │  │ Private      │  │ Private│    │
│  │  │ Subnet       │  │ Subnet       │  │ Subnet │    │
│  │  │ (EKS Nodes)  │  │ (EKS Nodes)  │  │        │    │
│  │  └──────────────┘  └──────────────┘  └────────┘    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Deploying Greenfield Cluster

After creating your EKS cluster:

### 1. Configure kubectl

```bash
# Configure kubectl access
aws eks update-kubeconfig \
  --region us-west-2 \
  --name greenfield-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### 2. Install EBS CSI Driver (if not installed)

Required for persistent volumes:

```bash
# Add IAM policy for EBS CSI driver
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster greenfield-cluster \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

# Install EBS CSI driver
eksctl create addon \
  --name aws-ebs-csi-driver \
  --cluster greenfield-cluster \
  --service-account-role-arn arn:aws:iam::ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole \
  --force
```

### 3. Deploy Greenfield

**Using Kustomize:**

```bash
# Deploy base configuration
kubectl apply -k kustomize/base/

# Or use environment overlay
kubectl apply -k kustomize/overlays/prod/
```

**Using Helm:**

```bash
helm install greenfield helm/greenfield-cluster \
  --namespace greenfield \
  --create-namespace \
  --values helm/greenfield-cluster/values-prod.yaml
```

### 4. Configure Load Balancer (Optional)

Install AWS Load Balancer Controller for ingress:

```bash
# Add IAM policy
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create service account
eksctl create iamserviceaccount \
  --cluster=greenfield-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=greenfield-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## Cost Optimization

### Estimated Monthly Costs

**Development (t4g.large, 3 nodes):**
- EKS Control Plane: $73
- Worker Nodes: ~$145 (3 × $0.0672/hr × 730hr)
- EBS Storage: ~$15 (300GB × $0.08/GB-month)
- **Total: ~$233/month**

**Production (t4g.xlarge, 5 nodes):**
- EKS Control Plane: $73
- Worker Nodes: ~$490 (5 × $0.1344/hr × 730hr)
- EBS Storage: ~$40 (500GB)
- Load Balancer: ~$20
- **Total: ~$623/month**

### Cost Reduction Tips

1. **Use ARM Graviton**: 15-20% savings over x86
2. **Spot Instances**: Up to 90% savings for non-critical workloads
3. **Auto-scaling**: Scale down during off-hours
4. **Reserved Instances**: Commit for 1-3 years for 40-60% savings
5. **Storage Optimization**: Use gp3 instead of gp2, cleanup unused volumes
6. **Right-sizing**: Monitor and adjust instance types

### Enable Spot Instances

For non-production or fault-tolerant workloads:

```hcl
# terraform.tfvars
use_spot_instances = true
spot_instance_types = ["t4g.large", "t4g.xlarge"]
```

Or with eksctl:

```yaml
managedNodeGroups:
  - name: spot-nodes
    instanceTypes: ["t4g.large", "t4g.xlarge"]
    spot: true
    desiredCapacity: 3
```

## Monitoring and Operations

### CloudWatch Container Insights

Enable Container Insights for cluster monitoring:

```bash
# Install CloudWatch agent
eksctl utils install-cw-logs \
  --cluster greenfield-cluster \
  --approve

# View metrics in CloudWatch Console
# CloudWatch → Container Insights
```

### Cluster Autoscaler

Install cluster autoscaler:

```bash
# Create IAM policy
cat <<EOF > cluster-autoscaler-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup",
        "ec2:DescribeImages",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    }
  ]
}
EOF

# Apply autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

## Security Best Practices

1. **IAM Roles**: Use IRSA (IAM Roles for Service Accounts)
2. **Network Policies**: Restrict pod-to-pod communication
3. **Secrets Management**: Use AWS Secrets Manager or Sealed Secrets
4. **Pod Security**: Enable Pod Security Standards
5. **VPC**: Use private subnets for worker nodes
6. **Encryption**: Enable EBS encryption at rest
7. **Updates**: Regular cluster and node updates

### Enable Encryption

```bash
# Encrypt secrets at rest
aws eks update-cluster-config \
  --name greenfield-cluster \
  --encryption-config "[{\"resources\":[\"secrets\"],\"provider\":{\"keyArn\":\"arn:aws:kms:us-west-2:ACCOUNT_ID:key/KEY_ID\"}}]"
```

## Troubleshooting

### Nodes Not Joining Cluster

```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name greenfield-cluster \
  --nodegroup-name greenfield-nodes

# Check IAM roles
eksctl get iamidentitymapping --cluster greenfield-cluster

# View node logs (SSH to node)
sudo journalctl -u kubelet
```

### Pods Stuck in Pending

```bash
# Check node resources
kubectl top nodes

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name greenfield-cluster \
  --nodegroup-name greenfield-nodes \
  --scaling-config desiredSize=5
```

### EBS Volume Issues

```bash
# Check CSI driver
kubectl get pods -n kube-system | grep ebs-csi

# Check storage class
kubectl get storageclass

# View PVC status
kubectl get pvc -n greenfield
```

## Cleanup

### Terraform

```bash
# Delete Greenfield resources first
kubectl delete -k kustomize/base/

# Destroy EKS cluster
cd infrastructure/aws/
terraform destroy
```

### eksctl

```bash
# Delete cluster (will take 10-15 minutes)
eksctl delete cluster --name greenfield-cluster --region us-west-2
```

### Manual

```bash
# Delete node group first
aws eks delete-nodegroup \
  --cluster-name greenfield-cluster \
  --nodegroup-name greenfield-nodes

# Wait for deletion, then delete cluster
aws eks delete-cluster --name greenfield-cluster
```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [eksctl Documentation](https://eksctl.io/)
- [AWS Graviton Technical Guide](https://github.com/aws/aws-graviton-getting-started)

## Next Steps

- [GCP GKE Deployment](gcp-gke.md)
- [Azure AKS Deployment](azure-aks.md)
- [Deployment Methods](methods.md)
- [Security Configuration](../security/overview.md)
