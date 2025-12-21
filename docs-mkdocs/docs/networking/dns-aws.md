# DNS Configuration for AWS Route 53

This guide shows you how to configure DNS records in AWS Route 53 to point to your Greenfield Cluster's ingress gateway.

## Overview

AWS Route 53 is Amazon's scalable DNS service. You'll create DNS records that point your domain to the LoadBalancer IP address of your Istio ingress gateway.

## Prerequisites

- AWS account with Route 53 access
- Domain registered (either in Route 53 or external registrar)
- Hosted zone created in Route 53 for your domain
- AWS CLI configured (optional, for CLI method)
- Greenfield Cluster deployed with Istio ingress gateway

## Get Your Ingress IP Address

First, get the external IP of your Istio ingress gateway:

```bash
# Get the LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system

# Store it in a variable
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# For EKS, you might get a hostname instead of IP
export INGRESS_HOSTNAME=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Ingress IP: $INGRESS_IP"
echo "Ingress Hostname: $INGRESS_HOSTNAME"
```

**Note:** On AWS EKS, the LoadBalancer service typically provides a hostname (ELB DNS name) rather than a static IP address. You'll use this hostname when creating DNS records.

## Method 1: AWS Console (Web UI)

### Step 1: Navigate to Route 53

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/)
2. Navigate to **Route 53** service
3. Click **Hosted zones** in the left sidebar

### Step 2: Select Your Hosted Zone

1. Click on the hosted zone for your domain (e.g., `greenfieldcluster.example`)
2. You should see existing NS and SOA records

### Step 3: Create A Record for Root Domain

1. Click **Create record**
2. Configure the record:
   - **Record name**: Leave empty (for root domain) or enter subdomain
   - **Record type**: Select **A - Routes traffic to an IPv4 address**
   - **Value**: Enter your `INGRESS_IP` (or see ALIAS option below)
   - **TTL**: `300` (5 minutes - good for testing)
   - **Routing policy**: Simple routing
3. Click **Create records**

**Alternative for EKS (using ALIAS record):**

If you have an ELB hostname instead of an IP:
1. **Record type**: Select **A - Routes traffic to an IPv4 address**
2. Toggle **Alias** to ON
3. **Route traffic to**: 
   - Select "Alias to Application and Classic Load Balancer"
   - Choose your region
   - Select the load balancer hostname
4. Click **Create records**

### Step 4: Create Wildcard A Record

1. Click **Create record** again
2. Configure the record:
   - **Record name**: `*` (asterisk for wildcard)
   - **Record type**: Select **A - Routes traffic to an IPv4 address**
   - **Value**: Enter your `INGRESS_IP` (same as above)
   - **TTL**: `300`
   - **Routing policy**: Simple routing
3. Click **Create records**

## Method 2: AWS CLI

### Step 1: Get Your Hosted Zone ID

```bash
# List hosted zones
aws route53 list-hosted-zones

# Get zone ID for your domain
export ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='greenfieldcluster.example.'].Id" \
  --output text | cut -d'/' -f3)

echo "Zone ID: $ZONE_ID"
```

### Step 2: Create DNS Records

#### Option A: Using IP Address (if available)

Create a JSON file for the DNS changes:

```bash
cat > dns-changes.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "greenfieldcluster.example",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$INGRESS_IP"
          }
        ]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.greenfieldcluster.example",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$INGRESS_IP"
          }
        ]
      }
    }
  ]
}
EOF
```

Apply the changes:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://dns-changes.json
```

#### Option B: Using ALIAS Records (for ELB hostname)

For AWS EKS with ELB:

```bash
# Get the hosted zone ID of the ELB
export ELB_ZONE_ID=$(aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?DNSName=='$INGRESS_HOSTNAME'].CanonicalHostedZoneNameID" \
  --output text)

cat > dns-alias-changes.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "greenfieldcluster.example",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ELB_ZONE_ID",
          "DNSName": "$INGRESS_HOSTNAME",
          "EvaluateTargetHealth": false
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.greenfieldcluster.example",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "$ELB_ZONE_ID",
          "DNSName": "$INGRESS_HOSTNAME",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://dns-alias-changes.json
```

## Method 3: Terraform

If you're using Terraform to manage your infrastructure:

```hcl
# Get the hosted zone
data "aws_route53_zone" "main" {
  name = "greenfieldcluster.example"
}

# Get the Kubernetes service
data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-system"
  }
}

# Root domain A record
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "greenfieldcluster.example"
  type    = "A"
  ttl     = 300
  records = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
}

# Wildcard A record
resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.greenfieldcluster.example"
  type    = "A"
  ttl     = 300
  records = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
}
```

For ALIAS records with ELB:

```hcl
# Root domain ALIAS record
resource "aws_route53_record" "root_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "greenfieldcluster.example"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_elb.ingress.zone_id
    evaluate_target_health = false
  }
}

# Wildcard ALIAS record
resource "aws_route53_record" "wildcard_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.greenfieldcluster.example"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_elb.ingress.zone_id
    evaluate_target_health = false
  }
}
```

Apply with:
```bash
terraform apply
```

## Verify DNS Configuration

### Check DNS Propagation

```bash
# Check root domain
dig greenfieldcluster.example

# Check wildcard
dig app.greenfieldcluster.example

# Check specific subdomain
dig api.greenfieldcluster.example

# Use Google's DNS for external check
dig @8.8.8.8 greenfieldcluster.example
```

### Test with nslookup

```bash
nslookup greenfieldcluster.example
nslookup app.greenfieldcluster.example
```

### Check AWS Route 53

```bash
# List records in hosted zone
aws route53 list-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --query "ResourceRecordSets[?Type=='A']"
```

## Additional Subdomain Records (Optional)

If you need specific subdomains in addition to the wildcard:

```bash
# Create specific subdomain record
cat > specific-subdomain.json <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.greenfieldcluster.example",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$INGRESS_IP"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://specific-subdomain.json
```

## DNS Record Types Explained

### A Record vs ALIAS Record

**A Record:**
- Points domain to an IPv4 address
- Standard DNS record type
- Use when you have a static IP

**ALIAS Record (AWS-specific):**
- Points domain to another AWS resource (like ELB)
- Free (no Route 53 query charges)
- Automatically updates if target resource changes
- Recommended for AWS resources
- Can be used for root domain (unlike CNAME)

### Wildcard Records

The wildcard record (`*.example.com`) matches any subdomain:
- `app.greenfieldcluster.example` ✓
- `api.greenfieldcluster.example` ✓
- `grafana.greenfieldcluster.example` ✓
- `anything.greenfieldcluster.example` ✓

## TTL Considerations

**Time to Live (TTL)** determines how long DNS resolvers cache your record:

- **Low TTL (300s = 5 minutes)**: 
  - Use during initial setup
  - Allows quick changes
  - Higher Route 53 query costs

- **High TTL (3600s = 1 hour or more)**:
  - Use after setup is stable
  - Lower query costs
  - Slower to propagate changes

**Recommendation:** Start with 300s, increase to 3600s once stable.

## Troubleshooting

### DNS Not Resolving

```bash
# Check if hosted zone exists
aws route53 list-hosted-zones | grep greenfieldcluster.example

# Check records
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID

# Verify NS records at registrar match Route 53
aws route53 get-hosted-zone --id $ZONE_ID
```

### Wrong IP Address

```bash
# Verify ingress IP is correct
kubectl get svc istio-ingressgateway -n istio-system

# Update the record
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://dns-changes.json
```

### Propagation Delays

DNS changes can take time to propagate:
- Route 53 updates: Usually instant (seconds)
- Global propagation: Up to 48 hours (typically 5-30 minutes)
- Local cache: Depends on TTL

Clear your local DNS cache:
```bash
# Linux
sudo systemd-resolve --flush-caches

# macOS
sudo dscacheutil -flushcache

# Windows
ipconfig /flushdns
```

## Cost Considerations

Route 53 pricing:
- **Hosted Zone**: $0.50/month per zone
- **Standard Queries**: $0.40 per million queries
- **ALIAS Queries**: Free (to AWS resources)

**Cost Optimization:**
- Use ALIAS records for AWS resources (free queries)
- Increase TTL to reduce query volume
- Delete unused hosted zones

## Security Best Practices

1. **Use DNSSEC**: Enable for additional security
```bash
aws route53 enable-hosted-zone-dnssec --hosted-zone-id $ZONE_ID
```

2. **Restrict Access**: Use IAM policies to limit who can modify DNS records

3. **Enable Query Logging**: Track DNS queries
```bash
aws route53 create-query-logging-config \
  --hosted-zone-id $ZONE_ID \
  --cloud-watch-logs-log-group-arn arn:aws:logs:region:account:log-group:name
```

4. **Use Resource Record Set Permissions**: Fine-grained control over records

## Next Steps

After configuring DNS:

1. [Configure TLS Certificates](../networking/ingress-configuration.md#certificate-configuration)
2. [Set up Istio Gateway](../networking/ingress-configuration.md#gateway-configuration)
3. [Create VirtualServices](../networking/ingress-configuration.md#virtualservice-configuration)

## Additional Resources

- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [Route 53 Pricing](https://aws.amazon.com/route53/pricing/)
- [AWS CLI Route 53 Reference](https://docs.aws.amazon.com/cli/latest/reference/route53/)
- [Ingress Configuration Guide](./ingress-configuration.md)
