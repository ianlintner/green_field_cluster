# DNS Configuration for Azure DNS

This guide shows you how to configure DNS records in Azure DNS to point to your Greenfield Cluster's ingress gateway.

## Overview

Azure DNS is Microsoft's cloud-based DNS hosting service. You'll create DNS records that point your domain to the LoadBalancer IP address of your Istio ingress gateway.

## Prerequisites

- Azure subscription with DNS zone access
- Domain registered (either in Azure or external registrar)
- DNS zone created in Azure for your domain
- Azure CLI configured (optional, for CLI method)
- Greenfield Cluster deployed on AKS with Istio ingress gateway

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

## Method 1: Azure Portal (Web UI)

### Step 1: Navigate to Azure DNS

1. Sign in to the [Azure Portal](https://portal.azure.com/)
2. Search for **DNS zones** in the search bar
3. Click on **DNS zones** service

### Step 2: Select Your DNS Zone

1. Click on your DNS zone (e.g., `greenfieldcluster.example`)
2. You should see existing NS and SOA records

### Step 3: Create A Record for Root Domain

1. Click **+ Record set** at the top
2. Configure the record:
   - **Name**: Leave empty or enter `@` (for root domain)
   - **Type**: Select **A**
   - **TTL**: `5` minutes (good for testing)
   - **TTL unit**: Minutes
   - **IP address**: Enter your `INGRESS_IP`
3. Click **OK**

### Step 4: Create Wildcard A Record

1. Click **+ Record set** again
2. Configure the record:
   - **Name**: `*` (asterisk for wildcard)
   - **Type**: Select **A**
   - **TTL**: `5` minutes
   - **TTL unit**: Minutes
   - **IP address**: Enter your `INGRESS_IP` (same as above)
3. Click **OK**

### Step 5: Verify Records

You should now see both records in the DNS zone:
- `@` or root record pointing to your IP
- `*` wildcard record pointing to your IP

## Method 2: Azure CLI

### Step 1: List DNS Zones

```bash
# Login to Azure (if not already)
az login

# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# List DNS zones
az network dns zone list --output table

# Set variables
export RESOURCE_GROUP="your-resource-group"
export DNS_ZONE="greenfieldcluster.example"
```

### Step 2: Create Root Domain A Record

```bash
# Create or update A record for root domain
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "@" \
  --ipv4-address $INGRESS_IP

# Set TTL
az network dns record-set a update \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "@" \
  --set ttl=300
```

### Step 3: Create Wildcard A Record

```bash
# Create or update wildcard A record
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "*" \
  --ipv4-address $INGRESS_IP

# Set TTL
az network dns record-set a update \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "*" \
  --set ttl=300
```

### Step 4: Verify Records

```bash
# List all A records
az network dns record-set a list \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --output table

# Show specific record
az network dns record-set a show \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "@"
```

## Method 3: Azure PowerShell

If you prefer PowerShell:

```powershell
# Connect to Azure
Connect-AzAccount

# Set context
Set-AzContext -SubscriptionId "YOUR_SUBSCRIPTION_ID"

# Variables
$ResourceGroup = "your-resource-group"
$ZoneName = "greenfieldcluster.example"
$IngressIP = "YOUR_INGRESS_IP"

# Create root domain A record
$Records = @()
$Records += New-AzDnsRecordConfig -IPv4Address $IngressIP
New-AzDnsRecordSet -Name "@" -RecordType A -ResourceGroupName $ResourceGroup `
  -TTL 300 -ZoneName $ZoneName -DnsRecords $Records

# Create wildcard A record
$Records = @()
$Records += New-AzDnsRecordConfig -IPv4Address $IngressIP
New-AzDnsRecordSet -Name "*" -RecordType A -ResourceGroupName $ResourceGroup `
  -TTL 300 -ZoneName $ZoneName -DnsRecords $Records

# List records
Get-AzDnsRecordSet -ResourceGroupName $ResourceGroup -ZoneName $ZoneName -RecordType A
```

## Method 4: Terraform

If you're using Terraform to manage your infrastructure:

```hcl
# Get the DNS zone
data "azurerm_dns_zone" "main" {
  name                = "greenfieldcluster.example"
  resource_group_name = "your-resource-group"
}

# Get the Kubernetes service
data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-system"
  }
}

# Root domain A record
resource "azurerm_dns_a_record" "root" {
  name                = "@"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
}

# Wildcard A record
resource "azurerm_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300
  records             = [data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.ip]
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

### Check Azure DNS

```bash
# List all A records
az network dns record-set a list \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE

# Show specific record details
az network dns record-set a show \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "@" \
  --output json
```

## Additional Subdomain Records (Optional)

If you need specific subdomains in addition to the wildcard:

### Using Azure CLI

```bash
# Create specific subdomain record
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "app" \
  --ipv4-address $INGRESS_IP

az network dns record-set a update \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "app" \
  --set ttl=300
```

### Using Azure Portal

1. Click **+ Record set**
2. Enter the subdomain name (e.g., `app`)
3. Select type **A**
4. Enter the IP address
5. Click **OK**

## Managing Multiple IP Addresses

If you need a record to point to multiple IPs (for redundancy):

```bash
# Add multiple IP addresses to a single record
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "app" \
  --ipv4-address $INGRESS_IP_1

az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "app" \
  --ipv4-address $INGRESS_IP_2
```

## TTL Considerations

**Time to Live (TTL)** determines how long DNS resolvers cache your record:

- **Low TTL (300s = 5 minutes)**: 
  - Use during initial setup
  - Allows quick changes
  - Higher DNS query load

- **High TTL (3600s = 1 hour or more)**:
  - Use after setup is stable
  - Lower query load
  - Slower to propagate changes

**Recommendation:** Start with 300s, increase to 3600s once stable.

### Update TTL

```bash
# Update TTL for a record
az network dns record-set a update \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "@" \
  --set ttl=3600
```

## Updating Existing Records

### Update IP Address

```bash
# Remove old IP
az network dns record-set a remove-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "@" \
  --ipv4-address "OLD_IP"

# Add new IP
az network dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --record-set-name "@" \
  --ipv4-address $INGRESS_IP
```

## Deleting Records

### Using Azure CLI

```bash
# Delete a specific record set
az network dns record-set a delete \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "subdomain" \
  --yes
```

### Using Azure Portal

1. Navigate to your DNS zone
2. Select the record you want to delete
3. Click **Delete**
4. Confirm deletion

## Troubleshooting

### DNS Not Resolving

```bash
# Check if DNS zone exists
az network dns zone show \
  --resource-group $RESOURCE_GROUP \
  --name $DNS_ZONE

# List name servers
az network dns zone show \
  --resource-group $RESOURCE_GROUP \
  --name $DNS_ZONE \
  --query nameServers

# Verify NS records at registrar match Azure DNS
```

### Wrong IP Address

```bash
# Verify ingress IP is correct
kubectl get svc istio-ingressgateway -n istio-system

# List current records
az network dns record-set a list \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE

# Update the record (remove old, add new)
# See "Updating Existing Records" section above
```

### Propagation Delays

DNS changes can take time to propagate:
- Azure DNS updates: Usually within 60 seconds
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

### Record Not Appearing

```bash
# Check if record was created successfully
az network dns record-set a show \
  --resource-group $RESOURCE_GROUP \
  --zone-name $DNS_ZONE \
  --name "@"

# Check activity log for errors
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --offset 1h
```

## Cost Considerations

Azure DNS pricing (as of 2024):
- **Hosted Zone**: $0.50/month per zone (first 25 zones)
- **DNS Queries**: First 1 billion queries/month: $0.40 per million queries
- **Additional Zones**: $0.10/month per zone (for zones 26-100)

**Cost Optimization:**
- Delete unused DNS zones
- Increase TTL to reduce query volume
- Monitor query volume with Azure Monitor

## Security Best Practices

1. **Use Azure RBAC**: Control who can modify DNS records
```bash
# Assign DNS Zone Contributor role
az role assignment create \
  --assignee user@example.com \
  --role "DNS Zone Contributor" \
  --scope "/subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP/providers/Microsoft.Network/dnszones/ZONE_NAME"
```

2. **Enable Activity Logging**: Track DNS changes
```bash
# View activity logs
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --resource-type "Microsoft.Network/dnszones"
```

3. **Use Azure Policy**: Enforce DNS naming conventions

4. **Lock DNS Zones**: Prevent accidental deletion
```bash
# Create lock
az lock create \
  --name DontDeleteDNS \
  --lock-type CanNotDelete \
  --resource-group $RESOURCE_GROUP \
  --resource-name $DNS_ZONE \
  --resource-type Microsoft.Network/dnszones
```

## Integration with AKS

### Automatic DNS Updates

If using External DNS with AKS:

```bash
# Install External DNS
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install external-dns bitnami/external-dns \
  --set provider=azure \
  --set azure.resourceGroup=$RESOURCE_GROUP \
  --set azure.tenantId=$TENANT_ID \
  --set azure.subscriptionId=$SUBSCRIPTION_ID \
  --set azure.useManagedIdentityExtension=true \
  --set policy=sync
```

This allows automatic DNS record creation from Kubernetes Ingress resources.

## Monitoring DNS

### Query Metrics

```bash
# View query metrics
az monitor metrics list \
  --resource "/subscriptions/SUBSCRIPTION_ID/resourceGroups/RESOURCE_GROUP/providers/Microsoft.Network/dnszones/ZONE_NAME" \
  --metric "QueryVolume" \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z
```

### Set Up Alerts

Create alerts for DNS query anomalies or zone changes through Azure Monitor.

## Next Steps

After configuring DNS:

1. [Configure TLS Certificates](../networking/ingress-configuration.md#certificate-configuration)
2. [Set up Istio Gateway](../networking/ingress-configuration.md#gateway-configuration)
3. [Create VirtualServices](../networking/ingress-configuration.md#virtualservice-configuration)

## Additional Resources

- [Azure DNS Documentation](https://docs.microsoft.com/en-us/azure/dns/)
- [Azure DNS Pricing](https://azure.microsoft.com/en-us/pricing/details/dns/)
- [Azure CLI DNS Reference](https://docs.microsoft.com/en-us/cli/azure/network/dns)
- [Ingress Configuration Guide](./ingress-configuration.md)
