# Contributing to Greenfield Cluster

Thank you for your interest in contributing to Greenfield Cluster! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with:
- A clear description of the problem
- Steps to reproduce the issue
- Expected vs actual behavior
- Environment details (K8s version, cloud provider, etc.)

### Suggesting Enhancements

We welcome feature requests! Please open an issue with:
- A clear description of the feature
- Use cases and benefits
- Any implementation ideas you have

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Setup

```bash
# Clone your fork
git clone https://github.com/your-username/green_field_cluster.git
cd green_field_cluster

# Create a test cluster (Minikube example)
minikube start --cpus=4 --memory=8192

# Test your changes
kubectl apply -k kustomize/base/
```

### Testing Guidelines

- Test on multiple environments if possible (local, cloud)
- Ensure all pods start successfully
- Test service connectivity
- Verify monitoring and tracing work correctly

### Code Style

- Follow existing patterns in the codebase
- Keep YAML files properly indented (2 spaces)
- Document any new features in the README
- Update relevant documentation

### Documentation

When adding new features:
- Update relevant README files
- Add examples if applicable
- Document configuration options
- Update architecture diagrams if needed

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome diverse perspectives
- Focus on what's best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## Questions?

Feel free to open an issue for any questions about contributing.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
