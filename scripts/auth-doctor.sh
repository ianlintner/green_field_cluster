#!/bin/bash
# Note: This script intentionally does NOT use 'set -e' so it can continue
# checking all components and report a complete summary, even if some checks fail

# auth-doctor.sh - Diagnose authentication setup and verify configuration
#
# Usage: ./scripts/auth-doctor.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

print_header() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((ERRORS++))
}

print_header "Authentication Module Doctor"
echo "This tool checks your authentication setup for common issues."
echo ""

# Check 1: Prerequisites
print_header "Checking Prerequisites"

# kubectl
if command -v kubectl &> /dev/null; then
    check_pass "kubectl is installed"
else
    check_fail "kubectl is not installed"
fi

# Kubernetes connection
if kubectl cluster-info &> /dev/null; then
    check_pass "Connected to Kubernetes cluster"
    CLUSTER_NAME=$(kubectl config current-context)
    echo "  Current context: ${CLUSTER_NAME}"
else
    check_fail "Cannot connect to Kubernetes cluster"
fi

# Check 2: Namespaces
print_header "Checking Namespaces"

if kubectl get namespace greenfield &> /dev/null; then
    check_pass "greenfield namespace exists"
else
    check_fail "greenfield namespace not found"
fi

if kubectl get namespace istio-system &> /dev/null; then
    check_pass "istio-system namespace exists"
else
    check_fail "istio-system namespace not found (Istio required)"
fi

if kubectl get namespace cert-manager &> /dev/null; then
    check_pass "cert-manager namespace exists"
else
    check_warn "cert-manager namespace not found (optional but recommended)"
fi

# Check 3: Auth Module Components
print_header "Checking Auth Module Components"

# oauth2-proxy
if kubectl get deployment oauth2-proxy -n greenfield &> /dev/null; then
    check_pass "oauth2-proxy deployment exists"
    
    # Check if running
    READY=$(kubectl get deployment oauth2-proxy -n greenfield -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment oauth2-proxy -n greenfield -o jsonpath='{.spec.replicas}')
    
    if [ "${READY}" = "${DESIRED}" ]; then
        check_pass "oauth2-proxy is running (${READY}/${DESIRED} replicas ready)"
    else
        check_fail "oauth2-proxy is not ready (${READY}/${DESIRED} replicas ready)"
    fi
else
    check_fail "oauth2-proxy deployment not found"
fi

# oauth2-proxy service
if kubectl get service oauth2-proxy -n greenfield &> /dev/null; then
    check_pass "oauth2-proxy service exists"
else
    check_fail "oauth2-proxy service not found"
fi

# Keycloak (optional)
if kubectl get deployment keycloak -n greenfield &> /dev/null; then
    check_pass "keycloak deployment exists"
    
    READY=$(kubectl get statefulset keycloak -n greenfield -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get statefulset keycloak -n greenfield -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [ "${READY}" = "${DESIRED}" ]; then
        check_pass "keycloak is running (${READY}/${DESIRED} replicas ready)"
    else
        check_warn "keycloak is not ready (${READY}/${DESIRED} replicas ready)"
    fi
else
    echo "  ℹ keycloak not deployed (optional)"
fi

# Check 4: Secrets
print_header "Checking Secrets"

if kubectl get secret oauth2-proxy-secret -n greenfield &> /dev/null; then
    check_pass "oauth2-proxy-secret exists"
    
    # Check secret keys
    CLIENT_ID=$(kubectl get secret oauth2-proxy-secret -n greenfield -o jsonpath='{.data.client-id}' 2>/dev/null)
    CLIENT_SECRET=$(kubectl get secret oauth2-proxy-secret -n greenfield -o jsonpath='{.data.client-secret}' 2>/dev/null)
    COOKIE_SECRET=$(kubectl get secret oauth2-proxy-secret -n greenfield -o jsonpath='{.data.cookie-secret}' 2>/dev/null)
    
    if [ -n "${CLIENT_ID}" ] && [ "${CLIENT_ID}" != "UkVQTEFDRV9XSVRIX0NMSUVOVF9JRA==" ]; then
        check_pass "client-id is set"
    else
        check_fail "client-id is not set or using placeholder"
    fi
    
    if [ -n "${CLIENT_SECRET}" ] && [ "${CLIENT_SECRET}" != "UkVQTEFDRV9XSVRIX0NMSUVOVF9TRUNSRVQ=" ]; then
        check_pass "client-secret is set"
    else
        check_fail "client-secret is not set or using placeholder"
    fi
    
    if [ -n "${COOKIE_SECRET}" ] && [ "${COOKIE_SECRET}" != "UkVQTEFDRV9XSVRIX0NPT0tJRV9TRUNSRVQ=" ]; then
        check_pass "cookie-secret is set"
    else
        check_fail "cookie-secret is not set or using placeholder"
    fi
else
    check_fail "oauth2-proxy-secret not found"
fi

# Check 5: Configuration
print_header "Checking Configuration"

if kubectl get configmap oauth2-proxy-config -n greenfield &> /dev/null; then
    check_pass "oauth2-proxy-config exists"
    
    ISSUER=$(kubectl get configmap oauth2-proxy-config -n greenfield -o jsonpath='{.data.oidc-issuer-url}')
    REDIRECT=$(kubectl get configmap oauth2-proxy-config -n greenfield -o jsonpath='{.data.redirect-url}')
    
    echo "  Issuer URL: ${ISSUER}"
    echo "  Redirect URL: ${REDIRECT}"
    
    if [[ "${ISSUER}" == *"example.com"* ]]; then
        check_warn "OIDC issuer URL uses example.com (update with actual issuer)"
    fi
    
    if [[ "${REDIRECT}" == *"example.com"* ]]; then
        check_warn "Redirect URL uses example.com (update with actual domain)"
    fi
else
    check_fail "oauth2-proxy-config not found"
fi

# Provider info
if kubectl get configmap provider-info -n greenfield &> /dev/null; then
    PROVIDER=$(kubectl get configmap provider-info -n greenfield -o jsonpath='{.data.provider}')
    check_pass "Provider configured: ${PROVIDER}"
else
    check_warn "provider-info ConfigMap not found"
fi

# Check 6: Istio Integration
print_header "Checking Istio Integration"

# Check for EnvoyFilter
if kubectl get envoyfilter oauth2-proxy-ext-authz -n istio-system &> /dev/null; then
    check_pass "EnvoyFilter for ext_authz exists"
else
    check_warn "EnvoyFilter for ext_authz not found (ingress-level auth disabled)"
fi

# Check for Gateway
if kubectl get gateway auth-gateway -n istio-system &> /dev/null; then
    check_pass "auth-gateway exists"
    
    HOSTS=$(kubectl get gateway auth-gateway -n istio-system -o jsonpath='{.spec.servers[0].hosts[*]}')
    echo "  Configured hosts: ${HOSTS}"
    
    if [[ "${HOSTS}" == *"example.com"* ]]; then
        check_warn "Gateway uses example.com (update with actual domain)"
    fi
else
    check_warn "auth-gateway not found"
fi

# Check 7: Protected Apps
print_header "Checking Protected Applications"

PROTECTED_VS=$(kubectl get virtualservice -n greenfield -l auth-enabled=true --no-headers 2>/dev/null | wc -l)
if [ "${PROTECTED_VS}" -gt 0 ]; then
    check_pass "Found ${PROTECTED_VS} protected application(s)"
    
    echo ""
    echo "  Protected applications:"
    kubectl get virtualservice -n greenfield -l auth-enabled=true -o custom-columns=NAME:.metadata.name,HOST:.spec.hosts[0] --no-headers | while read -r line; do
        echo "    - $line"
    done
else
    echo "  ℹ No protected applications found yet"
    echo "    To protect an app: ./scripts/auth-protect.sh APP HOST POLICY"
fi

# Check 8: Network Connectivity
print_header "Checking Network Connectivity"

# Check if oauth2-proxy service is accessible
if kubectl get service oauth2-proxy -n greenfield &> /dev/null; then
    SERVICE_IP=$(kubectl get service oauth2-proxy -n greenfield -o jsonpath='{.spec.clusterIP}')
    check_pass "oauth2-proxy service ClusterIP: ${SERVICE_IP}"
    
    # Try to reach the service (ping endpoint)
    if kubectl run -n greenfield curl-test --image=curlimages/curl:latest --rm -i --restart=Never --command -- curl -s -o /dev/null -w "%{http_code}" http://oauth2-proxy.greenfield.svc.cluster.local:4180/ping 2>&1 | grep -q "200"; then
        check_pass "oauth2-proxy /ping endpoint is accessible"
    else
        check_warn "Cannot verify oauth2-proxy /ping endpoint accessibility"
    fi
fi

# Check 9: OIDC Issuer Reachability (if possible)
print_header "Checking OIDC Issuer Reachability"

if kubectl get configmap oauth2-proxy-config -n greenfield &> /dev/null; then
    ISSUER=$(kubectl get configmap oauth2-proxy-config -n greenfield -o jsonpath='{.data.oidc-issuer-url}')
    
    if [[ ! "${ISSUER}" == *"example.com"* ]]; then
        WELLKNOWN="${ISSUER}/.well-known/openid-configuration"
        
        if kubectl run -n greenfield curl-test --image=curlimages/curl:latest --rm -i --restart=Never --command -- curl -s -o /dev/null -w "%{http_code}" "${WELLKNOWN}" 2>&1 | grep -q "200"; then
            check_pass "OIDC issuer is reachable: ${ISSUER}"
        else
            check_fail "Cannot reach OIDC issuer: ${ISSUER}"
            echo "    Verify issuer URL and network connectivity"
        fi
    else
        check_warn "Cannot check issuer reachability (using example.com)"
    fi
fi

# Summary
print_header "Summary"

echo ""
if [ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -eq 0 ]; then
    echo -e "${GREEN}All checks passed! ✓${NC}"
    echo "Your authentication setup looks good."
elif [ ${ERRORS} -eq 0 ]; then
    echo -e "${YELLOW}Checks completed with ${WARNINGS} warning(s) ⚠${NC}"
    echo "Your authentication setup is functional but has some warnings to address."
else
    echo -e "${RED}Checks completed with ${ERRORS} error(s) and ${WARNINGS} warning(s) ✗${NC}"
    echo "Please fix the errors before using authentication."
fi

echo ""
echo "For more information, see: ${REPO_ROOT}/kustomize/base/auth/base/README.md"
echo ""

exit ${ERRORS}
