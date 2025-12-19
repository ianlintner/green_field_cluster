#!/bin/bash
set -e

# auth-install.sh - Install authentication module with specified provider
#
# Usage: ./scripts/auth-install.sh PROVIDER DOMAIN
# Example: ./scripts/auth-install.sh azuread corp.example.com

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 PROVIDER DOMAIN"
    echo ""
    echo "Install authentication module with specified provider"
    echo ""
    echo "Arguments:"
    echo "  PROVIDER   Authentication provider (azuread, google, github, okta-saml, keycloak)"
    echo "  DOMAIN     Base domain for your cluster (e.g., example.com)"
    echo ""
    echo "Examples:"
    echo "  $0 azuread corp.example.com"
    echo "  $0 google startup.io"
    echo "  $0 github myorg.dev"
    echo "  $0 okta-saml enterprise.com"
    echo ""
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

PROVIDER=$1
DOMAIN=$2

# Validate provider
VALID_PROVIDERS=("azuread" "google" "github" "okta-saml" "keycloak")
if [[ ! " ${VALID_PROVIDERS[@]} " =~ " ${PROVIDER} " ]]; then
    echo -e "${RED}Error: Invalid provider '${PROVIDER}'${NC}"
    echo "Valid providers: ${VALID_PROVIDERS[*]}"
    exit 1
fi

echo -e "${GREEN}Installing authentication module...${NC}"
echo "Provider: ${PROVIDER}"
echo "Domain: ${DOMAIN}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if kustomize is available
if ! command -v kustomize &> /dev/null; then
    echo -e "${YELLOW}Warning: kustomize not found. Will use kubectl apply -k instead.${NC}"
fi

# Set overlay path
OVERLAY_PATH="${REPO_ROOT}/platform/auth/overlays/provider-${PROVIDER}"

# Check if overlay exists
if [ ! -d "${OVERLAY_PATH}" ]; then
    echo -e "${RED}Error: Provider overlay not found at ${OVERLAY_PATH}${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Creating namespace...${NC}"
kubectl create namespace greenfield --dry-run=client -o yaml | kubectl apply -f -

echo -e "${YELLOW}Step 2: Checking prerequisites...${NC}"

# Check if Istio is installed
if ! kubectl get namespace istio-system &> /dev/null; then
    echo -e "${RED}Error: Istio not found. Please install Istio first.${NC}"
    echo "Run: make install-prerequisites"
    exit 1
fi

# Check if cert-manager is installed
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo -e "${YELLOW}Warning: cert-manager not found. SSL/TLS certificates will not be issued automatically.${NC}"
    echo "To install: make install-prerequisites"
fi

echo -e "${YELLOW}Step 3: Creating ExternalSecret/SealedSecret stubs...${NC}"

# Create secret template file
SECRET_FILE="${REPO_ROOT}/platform/auth/overlays/provider-${PROVIDER}/secret-stub.yaml"
cat > "${SECRET_FILE}" << EOF
# OAuth2 Proxy Secrets
# 
# IMPORTANT: Replace these placeholder values with actual secrets!
# 
# Methods to create secrets:
# 1. Using kubectl (not recommended for production):
#    kubectl create secret generic oauth2-proxy-secret \\
#      --from-literal=client-id=YOUR_CLIENT_ID \\
#      --from-literal=client-secret=YOUR_CLIENT_SECRET \\
#      --from-literal=cookie-secret=\$(openssl rand -base64 32 | head -c 32) \\
#      -n greenfield
#
# 2. Using sealed-secrets (recommended):
#    kubectl create secret generic oauth2-proxy-secret \\
#      --from-literal=client-id=YOUR_CLIENT_ID \\
#      --from-literal=client-secret=YOUR_CLIENT_SECRET \\
#      --from-literal=cookie-secret=\$(openssl rand -base64 32 | head -c 32) \\
#      --dry-run=client -o yaml | \\
#      kubeseal -o yaml > sealed-secret.yaml
#    kubectl apply -f sealed-secret.yaml
#
# 3. Using external-secrets:
#    See external-secrets documentation for your secret backend

apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secret
  namespace: greenfield
type: Opaque
stringData:
  client-id: "REPLACE_WITH_CLIENT_ID"
  client-secret: "REPLACE_WITH_CLIENT_SECRET"
  cookie-secret: "REPLACE_WITH_COOKIE_SECRET"
EOF

echo -e "${GREEN}✓ Secret stub created: ${SECRET_FILE}${NC}"

echo -e "${YELLOW}Step 4: Updating configuration with domain...${NC}"

# Update configmap with domain
CONFIGMAP_FILE="${OVERLAY_PATH}/configmap.yaml"
if [ -f "${CONFIGMAP_FILE}" ]; then
    # Create backup
    cp "${CONFIGMAP_FILE}" "${CONFIGMAP_FILE}.bak"
    
    # Update domain placeholders (portable sed syntax)
    sed "s/example\\.com/${DOMAIN}/g" "${CONFIGMAP_FILE}" > "${CONFIGMAP_FILE}.tmp"
    mv "${CONFIGMAP_FILE}.tmp" "${CONFIGMAP_FILE}"
    
    echo -e "${GREEN}✓ Updated domain in ${CONFIGMAP_FILE}${NC}"
fi

echo -e "${YELLOW}Step 5: Building manifests...${NC}"

# Build with kustomize
BUILD_OUTPUT="${REPO_ROOT}/build/auth-${PROVIDER}.yaml"
mkdir -p "${REPO_ROOT}/build"

if command -v kustomize &> /dev/null; then
    kustomize build "${OVERLAY_PATH}" > "${BUILD_OUTPUT}"
else
    kubectl kustomize "${OVERLAY_PATH}" > "${BUILD_OUTPUT}"
fi

echo -e "${GREEN}✓ Built manifests to ${BUILD_OUTPUT}${NC}"

echo -e "${YELLOW}Step 6: Reviewing configuration...${NC}"
echo ""
echo "The following resources will be created:"
kubectl apply -f "${BUILD_OUTPUT}" --dry-run=client

echo ""
read -p "Do you want to proceed with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi

echo -e "${YELLOW}Step 7: Applying manifests...${NC}"

# Apply with kubectl
kubectl apply -f "${BUILD_OUTPUT}"

echo ""
echo -e "${GREEN}✓ Authentication module installed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Create secrets for oauth2-proxy (see ${SECRET_FILE})"
echo "2. Update provider-specific configuration:"

case ${PROVIDER} in
    azuread)
        echo "   - Update tenant ID in ${CONFIGMAP_FILE}"
        echo "   - Create App Registration in Azure Portal"
        echo "   - Configure redirect URI: https://auth.${DOMAIN}/oauth2/callback"
        ;;
    google)
        echo "   - Create OAuth 2.0 Client in Google Cloud Console"
        echo "   - Configure authorized redirect URI: https://auth.${DOMAIN}/oauth2/callback"
        ;;
    github)
        echo "   - Create OAuth App in GitHub"
        echo "   - Configure authorization callback URL: https://auth.${DOMAIN}/oauth2/callback"
        ;;
    okta-saml)
        echo "   - Configure Keycloak (will be deployed)"
        echo "   - Create SAML app in Okta"
        echo "   - Configure SAML broker in Keycloak"
        ;;
    keycloak)
        echo "   - Access Keycloak admin console"
        echo "   - Configure realms and clients"
        ;;
esac

echo ""
echo "3. Protect an application:"
echo "   ./scripts/auth-protect.sh myapp myapp.${DOMAIN} \"group:developers\""
echo ""
echo "4. Verify installation:"
echo "   ./scripts/auth-doctor.sh"
echo ""

# Show deployment status
echo -e "${YELLOW}Checking deployment status...${NC}"
echo ""
kubectl get pods -n greenfield -l app=oauth2-proxy

if [ "${PROVIDER}" = "okta-saml" ] || [ "${PROVIDER}" = "keycloak" ]; then
    echo ""
    kubectl get pods -n greenfield -l app=keycloak
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
