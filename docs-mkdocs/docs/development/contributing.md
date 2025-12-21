# Contributing to Greenfield Cluster

Thank you for your interest in contributing to Greenfield Cluster! We welcome contributions from the community.

## Ways to Contribute

### Reporting Bugs

Found a bug? Help us fix it!

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (K8s version, cloud provider, OS)
   - Relevant logs or screenshots

**Template:**
```markdown
## Description
Brief description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Kubernetes version:
- Cloud provider:
- Deployment method (Kustomize/Helm):
- Component versions:

## Additional Context
Logs, screenshots, etc.
```

### Suggesting Enhancements

Have an idea for improvement?

1. **Check existing feature requests**
2. **Open an issue** labeled "enhancement" with:
   - Clear description of the feature
   - Use cases and benefits
   - Proposed implementation (if any)
   - Examples from other projects (if applicable)

### Improving Documentation

Documentation improvements are always welcome!

- Fix typos or unclear explanations
- Add examples or use cases
- Improve diagrams or architecture descriptions
- Translate documentation

### Contributing Code

See [Development Guide](#development-setup) below.

## Development Setup

### Prerequisites

- **Git**: For version control
- **Docker**: For building images
- **Kubernetes cluster**: Local (Minikube, Kind) or cloud
- **kubectl**: Kubernetes CLI
- **kustomize**: For manifest management (or use `kubectl apply -k`)
- **Helm**: Optional, for Helm deployments

### Local Development Environment

#### Option 1: Minikube

```bash
# Install Minikube
# See: https://minikube.sigs.k8s.io/docs/start/

# Start cluster with sufficient resources
minikube start --cpus=4 --memory=8192 --disk-size=50g

# Enable addons
minikube addons enable storage-provisioner
minikube addons enable metrics-server
```

#### Option 2: Kind

```bash
# Install Kind
# See: https://kind.sigs.k8s.io/docs/user/quick-start/

# Create cluster
kind create cluster --name greenfield

# Or use our test script
./scripts/test-kind-cluster.sh
```

#### Option 3: Cloud Provider

Use a small dev cluster on your preferred cloud:
- [AWS EKS](../deployment/aws-eks.md)
- [GCP GKE](../deployment/gcp-gke.md)
- [Azure AKS](../deployment/azure-aks.md)

### Fork and Clone

```bash
# Fork the repository on GitHub
# Then clone your fork

git clone https://github.com/YOUR_USERNAME/green_field_cluster.git
cd green_field_cluster

# Add upstream remote
git remote add upstream https://github.com/ianlintner/green_field_cluster.git
```

### Make Changes

```bash
# Create a feature branch
git checkout -b feature/my-feature

# Make your changes
# Edit files, add features, fix bugs

# Test your changes locally
kubectl apply -k kustomize/base/
# or
helm install greenfield helm/greenfield-cluster --namespace greenfield --create-namespace
```

## Testing Your Changes

### Validate Manifests

```bash
# Validate Kustomize
kubectl kustomize kustomize/base/ > /dev/null && echo "Valid"

# Validate Helm
helm lint helm/greenfield-cluster

# Dry-run
kubectl apply -k kustomize/base/ --dry-run=server
```

### Test Deployment

```bash
# Deploy to your test cluster
kubectl apply -k kustomize/overlays/dev/

# Wait for pods to be ready
kubectl wait --for=condition=ready pod --all -n greenfield --timeout=600s

# Check all pods are running
kubectl get pods -n greenfield

# Test services
kubectl port-forward -n greenfield svc/fastapi-app 8000:8000 &
curl http://localhost:8000/health
```

### Run Automated Tests

```bash
# If tests exist
make test

# Or run Kind cluster test
./scripts/test-kind-cluster.sh
```

### Test on Multiple Environments

If possible, test on:
- Local cluster (Minikube/Kind)
- At least one cloud provider
- Different Kubernetes versions

## Code Style

### Kubernetes Manifests

- Use 2-space indentation
- Follow Kubernetes API conventions
- Include resource limits and requests
- Add labels and annotations
- Include health checks (liveness/readiness probes)

**Example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: greenfield
  labels:
    app: my-app
    version: v1.0.0
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
        version: v1.0.0
    spec:
      containers:
        - name: my-app
          image: my-app:v1.0.0
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

### Python Code

- Follow PEP 8
- Use type hints
- Add docstrings
- Include error handling

### Documentation

- Use clear, concise language
- Include code examples
- Add diagrams where helpful
- Test all commands and examples

## Commit Guidelines

### Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```bash
feat(redis): add sentinel support

Add Redis Sentinel configuration for high availability.
Includes StatefulSet, Service, and ConfigMap.

Closes #123

---

fix(postgres): correct backup script permissions

The backup script was not executable, causing cron jobs to fail.

Fixes #456

---

docs(deployment): add GCP GKE deployment guide

Comprehensive guide for deploying to Google Kubernetes Engine
including Terraform examples and best practices.
```

## Pull Request Process

### Before Submitting

1. **Update documentation** if needed
2. **Test thoroughly** on local cluster
3. **Run linting and validation**
4. **Update CHANGELOG** if applicable
5. **Ensure commits follow** commit guidelines

### Creating Pull Request

1. **Push to your fork:**
   ```bash
   git push origin feature/my-feature
   ```

2. **Create PR on GitHub** with:
   - Clear title describing the change
   - Detailed description of what and why
   - Link to related issues
   - Screenshots/logs if applicable
   - Checklist of testing done

**PR Template:**
```markdown
## Description
Brief description of changes

## Motivation and Context
Why is this change needed? What problem does it solve?

## How Has This Been Tested?
- [ ] Local Minikube cluster
- [ ] Kind cluster
- [ ] AWS EKS
- [ ] GCP GKE
- [ ] Azure AKS

## Types of Changes
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Checklist
- [ ] My code follows the code style of this project
- [ ] I have updated the documentation accordingly
- [ ] I have added tests to cover my changes
- [ ] All new and existing tests passed
- [ ] My changes generate no new warnings

## Screenshots (if applicable)

## Related Issues
Closes #XXX
```

### Review Process

1. **Automated checks** run (if configured)
2. **Maintainers review** your PR
3. **Address feedback** if any
4. **PR gets merged** once approved

### After Merge

1. **Delete your branch:**
   ```bash
   git branch -d feature/my-feature
   git push origin --delete feature/my-feature
   ```

2. **Update your fork:**
   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   ```

## Component-Specific Guidelines

### Adding New Components

When adding a new component (e.g., a new database):

1. **Create directory structure:**
   ```
   kustomize/base/new-component/
   ├── deployment.yaml (or statefulset.yaml)
   ├── service.yaml
   ├── configmap.yaml (if needed)
   ├── kustomization.yaml
   └── README.md
   ```

2. **Follow naming conventions:**
   - Labels: `app: component-name`
   - Services: `component-name-service`
   - ConfigMaps: `component-name-config`

3. **Add to base kustomization:**
   ```yaml
   # kustomize/base/kustomization.yaml
   resources:
     - new-component
   ```

4. **Create documentation:**
   ```
   docs-mkdocs/docs/components/new-component.md
   ```

5. **Update navigation:**
   ```yaml
   # docs-mkdocs/mkdocs.yml
   nav:
     - Components:
       - New Component: components/new-component.md
   ```

### Updating Components

- Test both upgrade and fresh install paths
- Document breaking changes
- Provide migration guide if needed
- Update version numbers consistently

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Focus on what is best for the community

### Getting Help

- **GitHub Issues**: For bugs and features
- **Discussions**: For questions and ideas
- **Documentation**: Check docs first

### Recognition

Contributors are recognized in:
- CONTRIBUTORS file
- Release notes
- Project README

## Additional Resources

- [Architecture Guide](../components/architecture.md)
- [Deployment Guide](../deployment/methods.md)
- [Security Best Practices](../security/best-practices.md)
- [Testing Guide](testing.md)

## Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort! 🎉
