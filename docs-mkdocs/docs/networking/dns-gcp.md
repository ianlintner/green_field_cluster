# DNS Configuration for Google Cloud DNS

This guide shows you how to configure DNS records in Google Cloud DNS to point to your Greenfield Cluster's ingress gateway.

## Overview

Google Cloud DNS is Google Cloud's scalable and reliable DNS service. You'll create DNS records that point your domain to the LoadBalancer IP address of your Istio ingress gateway.

## Prerequisites

- Google Cloud Platform (GCP) account
- Domain registered (either in Google Domains or external registrar)
- Cloud DNS managed zone created for your domain
- gcloud CLI configured (optional, for CLI method)
- Greenfield Cluster deployed on GKE with Istio ingress gateway

## Get Your Ingress IP Address

First, get the external IP of your Istio ingress gateway:

```bash
# Get the LoadBalancer IP
kubectl get svc istio-ingressgateway -n istio-system

# Store it in a variable
export INGRESS_IP=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress IP: $INGRESS_IP"
```

## Method 1: Google Cloud Console (Web UI)

### Step 1: Navigate to Cloud DNS

1. Sign in to the [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **Network Services** → **Cloud DNS**
3. Or search for "Cloud DNS" in the search bar

### Step 2: Select Your DNS Zone

1. Click on your managed zone (e.g., `greenfieldcluster-example`)
2. You should see existing NS and SOA records

### Step 3: Create A Record for Root Domain

1. Click **ADD RECORD SET**
2. Configure the record:
   - **DNS name**: Leave empty (for root domain) or enter `@`
   - **Resource record type**: Select **A**
   - **TTL**: `5` minutes (good for testing)
   - **TTL unit**: Minutes
   - **IPv4 Address**: Enter your `INGRESS_IP`
3. Click **CREATE**

### Step 4: Create Wildcard A Record

1. Click **ADD RECORD SET** again
2. Configure the record:
   - **DNS name**: `*` (asterisk for wildcard)
   - **Resource record type**: Select **A**
   - **TTL**: `5` minutes
   - **TTL unit**: Minutes
   - **IPv4 Address**: Enter your `INGRESS_IP` (same as above)
3. Click **CREATE**

### Step 5: Verify Records

You should now see both records in the DNS zone:
- Root record pointing to your IP
- `*` wildcard record pointing to your IP

## Method 2: gcloud CLI

### Step 1: Set Project and Variables

```bash
# Set your GCP project
gcloud config set project YOUR_PROJECT_ID

# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export DNS_ZONE="greenfieldcluster-example"  # Zone name (not domain)
export DOMAIN="greenfieldcluster.example."   # Domain with trailing dot
```

**Note:** DNS zone name and domain name are different:
- Zone name: `greenfieldcluster-example` (identifier in GCP)
- Domain name: `greenfieldcluster.example.` (actual domain with trailing dot)

### Step 2: Verify DNS Zone Exists

```bash
# List DNS zones
gcloud dns managed-zones list

# Describe specific zone
gcloud dns managed-zones describe $DNS_ZONE
```

### Step 3: Create Root Domain A Record

```bash
# Start a transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Add A record for root domain
gcloud dns record-sets transaction add $INGRESS_IP \
  --name=$DOMAIN \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Execute the transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

### Step 4: Create Wildcard A Record

```bash
# Start a new transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Add wildcard A record
gcloud dns record-sets transaction add $INGRESS_IP \
  --name="*.$DOMAIN" \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Execute the transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

### Step 5: Verify Records

```bash
# List all A records in the zone
gcloud dns record-sets list --zone=$DNS_ZONE --type=A

# View specific record
gcloud dns record-sets describe $DOMAIN --zone=$DNS_ZONE --type=A
```

## Method 3: Using Transaction Files

For bulk updates, you can use transaction files:

```bash
# Export current records
gcloud dns record-sets export records.yaml --zone=$DNS_ZONE

# Edit records.yaml to add your records
cat >> records.yaml <<EOF
- kind: dns#resourceRecordSet
  name: $DOMAIN
  rrdatas:
  - $INGRESS_IP
  ttl: 300
  type: A
- kind: dns#resourceRecordSet
  name: "*.$DOMAIN"
  rrdatas:
  - $INGRESS_IP
  ttl: 300
  type: A
EOF

# Import updated records
gcloud dns record-sets import records.yaml --zone=$DNS_ZONE --replace-origin-ns
```

## Method 4: Terraform

If you're using Terraform to manage your infrastructure:

```hcl
# Get the DNS zone
data "google_dns_managed_zone" "main" {
  name = "greenfieldcluster-example"
}

# Get the Kubernetes service
data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-system"
  }
}

# Root domain A record
resource "google_dns_record_set" "root" {
  name         = data.google_dns_managed_zone.main.dns_name
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.main.name
  rrdatas      = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
}

# Wildcard A record
resource "google_dns_record_set" "wildcard" {
  name         = "*.${data.google_dns_managed_zone.main.dns_name}"
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.main.name
  rrdatas      = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
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

# Use Google's public DNS
dig @8.8.8.8 greenfieldcluster.example

# Use Cloud DNS servers directly
dig @ns-cloud-a1.googledomains.com greenfieldcluster.example
```

### Test with nslookup

```bash
nslookup greenfieldcluster.example
nslookup app.greenfieldcluster.example
nslookup api.greenfieldcluster.example 8.8.8.8
```

### Check Cloud DNS Records

```bash
# List all records
gcloud dns record-sets list --zone=$DNS_ZONE

# Filter for A records
gcloud dns record-sets list --zone=$DNS_ZONE --type=A

# Show detailed record info
gcloud dns record-sets describe $DOMAIN --zone=$DNS_ZONE --type=A
```

## Additional Subdomain Records (Optional)

If you need specific subdomains in addition to the wildcard:

```bash
# Create specific subdomain record
gcloud dns record-sets transaction start --zone=$DNS_ZONE

gcloud dns record-sets transaction add $INGRESS_IP \
  --name="app.$DOMAIN" \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

## Updating Existing Records

### Update IP Address

```bash
# Start transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Remove old record
gcloud dns record-sets transaction remove OLD_IP \
  --name=$DOMAIN \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Add new record
gcloud dns record-sets transaction add $INGRESS_IP \
  --name=$DOMAIN \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Execute transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

### Update TTL

```bash
# Get current record
CURRENT_IP=$(gcloud dns record-sets describe $DOMAIN --zone=$DNS_ZONE --type=A --format="value(rrdatas[0])")

# Start transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Remove with old TTL
gcloud dns record-sets transaction remove $CURRENT_IP \
  --name=$DOMAIN \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Add with new TTL
gcloud dns record-sets transaction add $CURRENT_IP \
  --name=$DOMAIN \
  --ttl=3600 \
  --type=A \
  --zone=$DNS_ZONE

# Execute transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

## TTL Considerations

**Time to Live (TTL)** determines how long DNS resolvers cache your record:

- **Low TTL (300s = 5 minutes)**: 
  - Use during initial setup
  - Allows quick changes
  - Higher DNS query costs

- **High TTL (3600s = 1 hour or more)**:
  - Use after setup is stable
  - Lower query costs (queries are cached longer)
  - Slower to propagate changes

**Recommendation:** Start with 300s, increase to 3600s once stable.

## Deleting Records

```bash
# Start transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Remove record
gcloud dns record-sets transaction remove $INGRESS_IP \
  --name=$DOMAIN \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Execute transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

**Note:** You cannot delete NS and SOA records for your zone.

## Managing Multiple IP Addresses

If you need a record to point to multiple IPs (for load balancing):

```bash
# Start transaction
gcloud dns record-sets transaction start --zone=$DNS_ZONE

# Add record with multiple IPs
gcloud dns record-sets transaction add "$INGRESS_IP_1" "$INGRESS_IP_2" \
  --name="app.$DOMAIN" \
  --ttl=300 \
  --type=A \
  --zone=$DNS_ZONE

# Execute transaction
gcloud dns record-sets transaction execute --zone=$DNS_ZONE
```

## Troubleshooting

### Transaction Errors

If a transaction fails or is abandoned:

```bash
# Abort current transaction
gcloud dns record-sets transaction abort --zone=$DNS_ZONE

# Start fresh
gcloud dns record-sets transaction start --zone=$DNS_ZONE
```

### DNS Not Resolving

```bash
# Check if zone exists
gcloud dns managed-zones describe $DNS_ZONE

# List name servers
gcloud dns managed-zones describe $DNS_ZONE --format="value(nameServers)"

# Verify NS records at registrar match Cloud DNS
# Compare output above with registrar's NS records
```

### Wrong IP Address

```bash
# Verify ingress IP is correct
kubectl get svc istio-ingressgateway -n istio-system

# Check current DNS record
gcloud dns record-sets describe $DOMAIN --zone=$DNS_ZONE --type=A

# Update the record (see "Updating Existing Records" above)
```

### Propagation Delays

DNS changes can take time to propagate:
- Cloud DNS updates: Usually within 120 seconds
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

### Check DNS Propagation Status

```bash
# Check from different locations
dig @8.8.8.8 greenfieldcluster.example        # Google Public DNS
dig @1.1.1.1 greenfieldcluster.example        # Cloudflare DNS
dig @208.67.222.222 greenfieldcluster.example # OpenDNS

# Query authoritative servers directly
dig @ns-cloud-a1.googledomains.com greenfieldcluster.example
```

## Cloud DNS Features

### DNSSEC

Enable DNSSEC for additional security:

```bash
# Enable DNSSEC for zone
gcloud dns managed-zones update $DNS_ZONE --dnssec-state=on

# View DNSSEC config
gcloud dns managed-zones describe $DNS_ZONE --format="value(dnssecConfig)"
```

### Private DNS Zones

For internal cluster DNS:

```bash
# Create private zone
gcloud dns managed-zones create internal-zone \
  --description="Internal DNS zone" \
  --dns-name="internal.example." \
  --networks="default" \
  --visibility=private
```

## Cost Considerations

Cloud DNS pricing (as of 2024):
- **Hosted Zone**: $0.20/month per zone
- **DNS Queries**: First 1 billion queries/month: $0.40 per million queries
- **Additional Queries**: $0.20 per million (over 1 billion)

**Cost Optimization:**
- Use higher TTL values to reduce query volume
- Delete unused DNS zones
- Monitor query volume with Cloud Monitoring

## Security Best Practices

1. **Use IAM Roles**: Control who can modify DNS records
```bash
# Grant DNS Administrator role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=user:admin@example.com \
  --role=roles/dns.admin
```

2. **Enable DNSSEC**: Add cryptographic signatures to DNS data

3. **Audit Logging**: Track DNS changes
```bash
# View Cloud DNS logs
gcloud logging read "resource.type=dns_managed_zone" --limit=50
```

4. **Separate Zones**: Use different zones for dev/staging/prod

## Integration with GKE

### Using External DNS

Automatically manage DNS records from Kubernetes:

```bash
# Install External DNS
kubectl create namespace external-dns

# Create service account for External DNS
gcloud iam service-accounts create external-dns \
  --display-name="External DNS"

# Grant permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:external-dns@$PROJECT_ID.iam.gserviceaccount.com \
  --role=roles/dns.admin

# Deploy External DNS
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install external-dns bitnami/external-dns \
  --namespace external-dns \
  --set provider=google \
  --set google.project=$PROJECT_ID \
  --set policy=sync \
  --set registry=txt \
  --set txtOwnerId=gke-cluster
```

This allows automatic DNS record creation from Kubernetes Ingress and Service resources.

## Monitoring DNS

### Query Metrics

View DNS query metrics in Cloud Monitoring:

```bash
# List available metrics
gcloud monitoring metrics-descriptors list \
  --filter="metric.type:dns.googleapis.com"

# Example: Query volume over time
gcloud monitoring time-series list \
  --filter='metric.type="dns.googleapis.com/query_count"' \
  --start-time="2024-01-01T00:00:00Z" \
  --end-time="2024-01-02T00:00:00Z"
```

### Set Up Alerts

Create alerts for DNS query anomalies or high error rates through Cloud Monitoring.

## Backup and Recovery

### Export Zone Data

```bash
# Export zone to file
gcloud dns record-sets export backup.yaml \
  --zone=$DNS_ZONE

# Store in Cloud Storage for backup
gsutil cp backup.yaml gs://your-backup-bucket/dns-backup-$(date +%Y%m%d).yaml
```

### Import Zone Data

```bash
# Import from backup
gcloud dns record-sets import backup.yaml \
  --zone=$DNS_ZONE \
  --replace-origin-ns
```

## Next Steps

After configuring DNS:

1. [Configure TLS Certificates](../networking/ingress-configuration.md#certificate-configuration)
2. [Set up Istio Gateway](../networking/ingress-configuration.md#gateway-configuration)
3. [Create VirtualServices](../networking/ingress-configuration.md#virtualservice-configuration)

## Additional Resources

- [Cloud DNS Documentation](https://cloud.google.com/dns/docs)
- [Cloud DNS Pricing](https://cloud.google.com/dns/pricing)
- [gcloud DNS Reference](https://cloud.google.com/sdk/gcloud/reference/dns)
- [DNS Best Practices](https://cloud.google.com/dns/docs/best-practices)
- [Ingress Configuration Guide](./ingress-configuration.md)
