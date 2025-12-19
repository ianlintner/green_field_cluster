#!/bin/bash
set -e

# auth-add-provider.sh - Add a new authentication provider overlay
#
# Usage: ./scripts/auth-add-provider.sh PROVIDER
# Example: ./scripts/auth-add-provider.sh okta-oidc

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 PROVIDER"
    echo ""
    echo "Add a new authentication provider overlay"
    echo ""
    echo "Arguments:"
    echo "  PROVIDER   Provider name (e.g., okta-oidc, auth0, cognito)"
    echo ""
    echo "Examples:"
    echo "  $0 okta-oidc"
    echo "  $0 auth0"
    echo "  $0 cognito"
    echo ""
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

PROVIDER=$1
OVERLAY_DIR="${REPO_ROOT}/platform/auth/overlays/provider-${PROVIDER}"

echo -e "${GREEN}Adding new authentication provider: ${PROVIDER}${NC}"
echo ""

# Check if overlay already exists
if [ -d "${OVERLAY_DIR}" ]; then
    echo -e "${RED}Error: Provider overlay already exists at ${OVERLAY_DIR}${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating provider overlay directory...${NC}"
mkdir -p "${OVERLAY_DIR}"

echo -e "${YELLOW}Generating configuration files...${NC}"

# Prompt for provider details
echo ""
echo "Please provide the following information for ${PROVIDER}:"
echo ""
read -p "OIDC Issuer URL: " ISSUER_URL
read -p "Provider type (oidc/oauth2/saml): " PROVIDER_TYPE
read -p "Requires special configuration? (y/n): " SPECIAL_CONFIG

# Create configmap.yaml
cat > "${OVERLAY_DIR}/configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
  namespace: greenfield
data:
  # ${PROVIDER} Configuration
  oidc-issuer-url: "${ISSUER_URL}"
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
  whitelist-domains: ".example.com"
EOF

# Create deployment-patch.yaml
cat > "${OVERLAY_DIR}/deployment-patch.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: greenfield
spec:
  template:
    spec:
      containers:
      - name: oauth2-proxy
        env:
        - name: OAUTH2_PROXY_PROVIDER
          value: "${PROVIDER_TYPE}"
        # Add provider-specific environment variables here
EOF

# Create kustomization.yaml
cat > "${OVERLAY_DIR}/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: greenfield

bases:
  - ../../base

patchesStrategicMerge:
  - configmap.yaml
  - deployment-patch.yaml

configMapGenerator:
  - name: provider-info
    literals:
      - provider=${PROVIDER}
      - provider-type=${PROVIDER_TYPE}
      - issuer-url=${ISSUER_URL}

generatorOptions:
  disableNameSuffixHash: true
EOF

# Create README.md
cat > "${OVERLAY_DIR}/README.md" << EOF
# ${PROVIDER} Provider Configuration

This overlay configures oauth2-proxy for ${PROVIDER} authentication.

## Prerequisites

1. **${PROVIDER} Setup**
   - TODO: Add provider setup instructions
   - Create OAuth/OIDC application
   - Note the Client ID and Client Secret

2. **Configure Redirect URI**
   \`\`\`
   https://auth.example.com/oauth2/callback
   \`\`\`

## Configuration Steps

### 1. Update Configuration

Edit \`configmap.yaml\`:
\`\`\`yaml
data:
  oidc-issuer-url: "${ISSUER_URL}"
  redirect-url: "https://auth.example.com/oauth2/callback"
  cookie-domains: ".example.com"
\`\`\`

### 2. Create Secrets

\`\`\`bash
kubectl create secret generic oauth2-proxy-secret \\
  --from-literal=client-id=YOUR_CLIENT_ID \\
  --from-literal=client-secret=YOUR_CLIENT_SECRET \\
  --from-literal=cookie-secret=\$(openssl rand -base64 32 | head -c 32) \\
  -n greenfield
\`\`\`

### 3. Deploy

\`\`\`bash
kubectl apply -k platform/auth/overlays/provider-${PROVIDER}/
\`\`\`

## Testing

\`\`\`bash
# Check logs
kubectl logs -n greenfield -l app=oauth2-proxy

# Test authentication
curl -I https://myapp.example.com
# Should redirect to ${PROVIDER} login
\`\`\`

## Troubleshooting

### Common Issues

TODO: Add provider-specific troubleshooting tips

## References

- TODO: Add links to ${PROVIDER} documentation
- [oauth2-proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
EOF

echo -e "${GREEN}✓ Provider overlay created successfully!${NC}"
echo ""
echo "Created files:"
echo "  - ${OVERLAY_DIR}/configmap.yaml"
echo "  - ${OVERLAY_DIR}/deployment-patch.yaml"
echo "  - ${OVERLAY_DIR}/kustomization.yaml"
echo "  - ${OVERLAY_DIR}/README.md"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review and customize the generated files"
echo "2. Update ${OVERLAY_DIR}/README.md with provider-specific instructions"
echo "3. Add any provider-specific environment variables to deployment-patch.yaml"
echo "4. Test the provider overlay:"
echo "   kubectl apply -k ${OVERLAY_DIR} --dry-run=client"
echo ""

if [[ "${SPECIAL_CONFIG}" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Provider requires special configuration:${NC}"
    echo "- Review oauth2-proxy documentation for ${PROVIDER}"
    echo "- Add necessary ConfigMaps, Secrets, or other resources"
    echo "- Update deployment-patch.yaml with provider-specific settings"
    echo ""
fi

echo -e "${GREEN}Provider addition complete!${NC}"
