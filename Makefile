# Makefile for Greenfield Cluster

.PHONY: help validate build-kustomize build-base build-dev build-staging build-prod deploy-dev deploy-staging deploy-prod clean test

# Default target
help:
	@echo "Greenfield Cluster - Makefile Commands"
	@echo ""
	@echo "Validation:"
	@echo "  make validate           - Validate all Kubernetes manifests"
	@echo "  make validate-base      - Validate base kustomization"
	@echo "  make validate-overlays  - Validate all overlays"
	@echo ""
	@echo "Build:"
	@echo "  make build-base         - Build base kustomization"
	@echo "  make build-dev          - Build dev overlay"
	@echo "  make build-staging      - Build staging overlay"
	@echo "  make build-prod         - Build prod overlay"
	@echo ""
	@echo "Deploy:"
	@echo "  make deploy-dev         - Deploy to dev environment"
	@echo "  make deploy-staging     - Deploy to staging environment"
	@echo "  make deploy-prod        - Deploy to production environment"
	@echo ""
	@echo "Docker:"
	@echo "  make build-fastapi      - Build FastAPI Docker image"
	@echo "  make push-fastapi       - Push FastAPI image to registry"
	@echo ""
	@echo "Testing:"
	@echo "  make test               - Run basic connectivity tests"
	@echo "  make port-forward       - Set up port forwarding for all services"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean-dev          - Remove dev deployment"
	@echo "  make clean-staging      - Remove staging deployment"
	@echo "  make clean-prod         - Remove prod deployment"

# Validation
validate: validate-base validate-overlays

validate-base:
	@echo "Validating base kustomization..."
	@kustomize build kustomize/base/ > /dev/null
	@echo "✓ Base kustomization is valid"

validate-overlays:
	@echo "Validating overlays..."
	@kustomize build kustomize/overlays/dev/ > /dev/null
	@echo "✓ Dev overlay is valid"
	@kustomize build kustomize/overlays/staging/ > /dev/null
	@echo "✓ Staging overlay is valid"
	@kustomize build kustomize/overlays/prod/ > /dev/null
	@echo "✓ Prod overlay is valid"

# Build
build-base:
	@mkdir -p build
	@kustomize build kustomize/base/ > build/base.yaml
	@echo "✓ Built base to build/base.yaml"

build-dev:
	@mkdir -p build
	@kustomize build kustomize/overlays/dev/ > build/dev.yaml
	@echo "✓ Built dev overlay to build/dev.yaml"

build-staging:
	@mkdir -p build
	@kustomize build kustomize/overlays/staging/ > build/staging.yaml
	@echo "✓ Built staging overlay to build/staging.yaml"

build-prod:
	@mkdir -p build
	@kustomize build kustomize/overlays/prod/ > build/prod.yaml
	@echo "✓ Built prod overlay to build/prod.yaml"

# Deploy
deploy-dev:
	@echo "Deploying to dev environment..."
	@kubectl apply -k kustomize/overlays/dev/
	@echo "✓ Deployed to dev"
	@echo "Waiting for pods to be ready..."
	@kubectl wait --for=condition=ready pod --all -n greenfield-dev --timeout=600s || true

deploy-staging:
	@echo "Deploying to staging environment..."
	@kubectl apply -k kustomize/overlays/staging/
	@echo "✓ Deployed to staging"

deploy-prod:
	@echo "Deploying to production environment..."
	@kubectl apply -k kustomize/overlays/prod/
	@echo "✓ Deployed to production"

# Docker
build-fastapi:
	@echo "Building FastAPI Docker image..."
	@cd apps/fastapi-example && docker build -t fastapi-example:latest .
	@echo "✓ Built fastapi-example:latest"

push-fastapi:
	@echo "Please set REGISTRY variable (e.g., make push-fastapi REGISTRY=myregistry.io/myproject)"
	@test -n "$(REGISTRY)" || (echo "Error: REGISTRY not set" && exit 1)
	@docker tag fastapi-example:latest $(REGISTRY)/fastapi-example:latest
	@docker push $(REGISTRY)/fastapi-example:latest
	@echo "✓ Pushed to $(REGISTRY)/fastapi-example:latest"

# Testing
test:
	@echo "Running basic connectivity tests..."
	@echo "Note: Ensure port-forwarding is active"
	@curl -s http://localhost:8000/health || echo "FastAPI not accessible"
	@curl -s http://localhost:8000/redis || echo "Redis test failed"
	@curl -s http://localhost:8000/postgres || echo "Postgres test failed"

port-forward:
	@echo "Setting up port forwarding..."
	@echo "FastAPI: http://localhost:8000"
	@kubectl port-forward -n greenfield svc/fastapi-app 8000:8000 &
	@echo "Grafana: http://localhost:3000"
	@kubectl port-forward -n greenfield svc/grafana 3000:3000 &
	@echo "Jaeger: http://localhost:16686"
	@kubectl port-forward -n greenfield svc/jaeger-query 16686:16686 &
	@echo "Prometheus: http://localhost:9090"
	@kubectl port-forward -n greenfield svc/prometheus 9090:9090 &
	@echo "✓ Port forwarding active"

# Cleanup
clean-dev:
	@echo "Removing dev deployment..."
	@kubectl delete -k kustomize/overlays/dev/ --ignore-not-found=true
	@echo "✓ Dev deployment removed"

clean-staging:
	@echo "Removing staging deployment..."
	@kubectl delete -k kustomize/overlays/staging/ --ignore-not-found=true
	@echo "✓ Staging deployment removed"

clean-prod:
	@echo "Removing production deployment..."
	@kubectl delete -k kustomize/overlays/prod/ --ignore-not-found=true
	@echo "✓ Production deployment removed"

# Install prerequisites
install-prerequisites:
	@echo "Installing prerequisites..."
	@echo "Installing cert-manager..."
	@kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
	@echo "Waiting for cert-manager to be ready..."
	@kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager || true
	@kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager || true
	@kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager || true
	@echo "Installing cert-manager ClusterIssuers..."
	@kubectl apply -k kustomize/base/cert-manager/
	@echo "Installing Istio..."
	@curl -L https://istio.io/downloadIstio | sh -
	@cd istio-* && export PATH=$$PWD/bin:$$PATH && istioctl install --set profile=default -y
	@echo "Installing Sealed Secrets..."
	@kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.5/controller.yaml
	@echo "✓ Prerequisites installed"
