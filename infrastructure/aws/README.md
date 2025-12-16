# AWS EKS Infrastructure

This Terraform configuration creates a minimal EKS cluster for running the Greenfield project.

## Features

- **ARM Support**: Uses AWS Graviton (ARM-based) instances by default for better price/performance
- **Minimal Configuration**: Optimized for cost-effectiveness
- **Production Ready**: Can scale up for production workloads
- **Auto-configured**: Includes EBS CSI driver for persistent volumes

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

### 1. Configure Variables (Optional)

Create a `terraform.tfvars` file:

```hcl
cluster_name     = "my-greenfield-cluster"
aws_region       = "us-west-2"
environment      = "dev"
use_arm          = true  # Set to false for x86 instances
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Plan the Infrastructure

```bash
terraform plan
```

### 4. Create the Cluster

```bash
terraform apply
```

This will take approximately 10-15 minutes.

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region us-west-2 --name greenfield-cluster
```

Or use the output command:

```bash
$(terraform output -raw configure_kubectl)
```

### 6. Verify Cluster

```bash
kubectl get nodes
```

### 7. Deploy Greenfield

```bash
# Go back to the repository root
cd ../..

# Deploy using Kustomize
kubectl apply -k kustomize/overlays/dev/

# Or deploy using Helm
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## Architecture

### Default Configuration

- **Region**: us-west-2
- **Node Type**: t4g.large (ARM Graviton) or t3.large (x86)
- **Node Count**: 2-6 nodes (3 desired)
- **VPC**: 10.0.0.0/16 with public and private subnets
- **NAT Gateway**: Single NAT gateway (for cost savings)
- **Kubernetes Version**: 1.28

### Instance Types

#### ARM (Graviton) - Default
- **t4g.large**: 2 vCPU, 8 GiB RAM (~$0.0672/hour)
- **t4g.xlarge**: 4 vCPU, 16 GiB RAM (~$0.1344/hour)

#### x86 - Fallback
- **t3.large**: 2 vCPU, 8 GiB RAM (~$0.0832/hour)
- **t3.xlarge**: 4 vCPU, 16 GiB RAM (~$0.1664/hour)

## Cost Optimization

### Development/Testing
Use the default configuration with:
- Single NAT gateway
- 2-3 ARM nodes
- Auto-scaling enabled

**Estimated cost**: ~$200-300/month

### Production
For production workloads:

```hcl
single_nat_gateway      = false  # HA setup
node_group_min_size     = 3
node_group_desired_size = 4
```

## Customization

### Use x86 Instances Instead of ARM

```hcl
use_arm = false
```

### Change Instance Types

```hcl
arm_instance_types = ["t4g.xlarge", "t4g.2xlarge"]
```

### Modify Node Scaling

```hcl
node_group_min_size     = 3
node_group_max_size     = 10
node_group_desired_size = 5
```

## Cleanup

To destroy the infrastructure:

```bash
# First, delete all Kubernetes resources
kubectl delete -k ../../kustomize/overlays/dev/

# Then destroy the infrastructure
terraform destroy
```

**Warning**: This will delete all resources including persistent volumes!

## Security Considerations

1. **IAM Roles**: The module creates appropriate IAM roles for EKS
2. **Network**: Uses private subnets for nodes
3. **Security Groups**: Managed by the EKS module
4. **Secrets**: Use AWS Secrets Manager or Sealed Secrets for sensitive data
5. **Updates**: Keep Kubernetes and node AMIs updated

## Troubleshooting

### Cluster Creation Fails

Check AWS service quotas:
```bash
aws service-quotas get-service-quota \
  --service-code eks \
  --quota-code L-1194D53C
```

### Nodes Not Joining

Verify the node group status:
```bash
aws eks describe-nodegroup \
  --cluster-name greenfield-cluster \
  --nodegroup-name greenfield-cluster-arm-nodes
```

### ARM Compatibility Issues

If you encounter ARM compatibility issues with specific workloads:
```hcl
use_arm = false
```

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Graviton Performance](https://aws.amazon.com/ec2/graviton/)
- [EKS Pricing](https://aws.amazon.com/eks/pricing/)
