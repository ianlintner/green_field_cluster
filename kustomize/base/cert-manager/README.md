# cert-manager Installation Guide

This directory contains the configuration for cert-manager, which automates the management and issuance of TLS certificates.

## ⚠️ Important: Update Email Address

**Before deploying to any environment, you MUST update the email address in:**
- `cluster-issuer-letsencrypt-staging.yaml`
- `cluster-issuer-letsencrypt-prod.yaml`

The email address is used for Let's Encrypt notifications about certificate expiration and account issues.

## Installation

cert-manager should be installed as a cluster-wide component before applying the ClusterIssuer configurations.

### Using kubectl:

```bash
# Install cert-manager CRDs
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.crds.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

### Using Helm:

```bash
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.0 \
  --set installCRDs=true
```

## ClusterIssuers

After cert-manager is installed, apply the ClusterIssuer configurations:

```bash
# Apply ClusterIssuers
kubectl apply -f cluster-issuer-letsencrypt-staging.yaml
kubectl apply -f cluster-issuer-letsencrypt-prod.yaml
```

### Let's Encrypt Staging

Use the staging issuer for testing to avoid rate limits:
- Issuer name: `letsencrypt-staging`
- ACME server: Let's Encrypt staging environment
- Use for development and testing

### Let's Encrypt Production

Use the production issuer for real certificates:
- Issuer name: `letsencrypt-prod`
- ACME server: Let's Encrypt production environment
- Subject to rate limits (50 certificates per registered domain per week)

## Usage with Ingress

To use cert-manager with your Ingress resources, add these annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: example-service
            port:
              number: 80
```

## Usage with Istio Gateway

For Istio Gateway resources, create a Certificate resource:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
  namespace: istio-system
spec:
  secretName: example-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  - www.example.com
```

Then reference the secret in your Gateway:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: example-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: example-tls
    hosts:
    - example.com
```

## Verification

Check cert-manager status:

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuers
kubectl get clusterissuer

# Check certificates
kubectl get certificate -A

# Describe a certificate for details
kubectl describe certificate <certificate-name> -n <namespace>
```

## Troubleshooting

View cert-manager logs:

```bash
kubectl logs -n cert-manager deployment/cert-manager
kubectl logs -n cert-manager deployment/cert-manager-webhook
```

Check certificate status:

```bash
kubectl describe certificate <certificate-name> -n <namespace>
kubectl describe certificaterequest -n <namespace>
kubectl describe order -n <namespace>
kubectl describe challenge -n <namespace>
```

## Important Notes

- **Email Address**: Update the email address in ClusterIssuer configurations with your actual email
- **DNS**: Ensure your domain's DNS is properly configured to point to your cluster's ingress
- **HTTP-01 Challenge**: Requires port 80 to be accessible for Let's Encrypt validation
- **Rate Limits**: Let's Encrypt has rate limits - use staging for testing
