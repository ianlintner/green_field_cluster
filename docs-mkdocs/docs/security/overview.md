# Security Overview

The greenfield cluster includes multiple security features to protect your applications and data.

## Security Components

### SSL/TLS Certificate Management

**cert-manager** provides automated certificate management:
- Automated certificate issuance from Let's Encrypt
- Automatic certificate renewal before expiration
- Support for both staging and production environments
- Integration with Istio for TLS termination

See the [cert-manager documentation](../components/cert-manager.md) for details.

### Encrypted Secrets Management

**Sealed Secrets** provides encryption for Kubernetes secrets:
- Secrets encrypted before committing to Git
- Safe to store in version control
- Decrypted only by the cluster controller
- Prevents accidental exposure of sensitive data

See the [Sealed Secrets documentation](./sealed-secrets.md) for setup instructions.

### Service Mesh Security

**Istio** provides multiple security features:
- **TLS Termination**: Secure external traffic with HTTPS
- **mTLS**: Mutual TLS for internal service-to-service communication
- **Traffic Encryption**: Automatic encryption of traffic between services
- **Gateway Separation**: Separate gateways for external and internal traffic

See the [Istio documentation](../components/istio.md) for configuration.

## Security Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Internet / Clients                         │
└────────────────────────┬─────────────────────────────────────┘
                         │ HTTPS (TLS encrypted)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│          Istio External Ingress Gateway                       │
│  - TLS Termination (cert-manager certificates)                │
│  - LoadBalancer (public IP)                                   │
└────────────────────────┬─────────────────────────────────────┘
                         │
              ┌──────────┴──────────┐
              │                     │
┌─────────────▼──────┐   ┌─────────▼──────────┐
│  External Services │   │  Internal Gateway  │
│  - API             │   │  - ClusterIP       │
│  - Web Apps        │   │  - mTLS            │
└─────────────┬──────┘   └─────────┬──────────┘
              │                     │
              └──────────┬──────────┘
                         │ mTLS encrypted
┌────────────────────────▼─────────────────────────────────────┐
│              Application Services                             │
│  - Encrypted in transit (mTLS)                                │
│  - Sealed secrets for credentials                             │
│  - No plain-text secrets in Git                               │
└───────────────────────────────────────────────────────────────┘
```

## Best Practices

### SSL/TLS Certificates

1. **Use Staging First**: Test with Let's Encrypt staging to avoid rate limits
2. **Update Email**: Set a valid email in ClusterIssuer for notifications
3. **Monitor Expiration**: Watch certificate expiration (cert-manager auto-renews)
4. **DNS Configuration**: Ensure DNS points to LoadBalancer IP before requesting certificates

### Secrets Management

1. **Never Commit Plain Secrets**: Always use Sealed Secrets for Git
2. **Rotate Regularly**: Update passwords and keys periodically
3. **Least Privilege**: Grant minimal permissions needed
4. **Audit Access**: Monitor who accesses secrets

### Network Security

1. **Separate Gateways**: Use different gateways for external and internal traffic
2. **Enable mTLS**: Use mutual TLS for internal service communication
3. **Limit Exposure**: Only expose necessary services publicly
4. **Use Network Policies**: Restrict traffic between pods (optional)

### Default Passwords

**⚠️ IMPORTANT**: This repository contains default passwords for demonstration purposes.

**DO NOT use these passwords in production!**

Before deploying to any non-development environment:
1. Change all database passwords
2. Update Grafana admin password
3. Regenerate all secrets
4. Use Sealed Secrets to encrypt them

See the [main README](../../../README.md) for the security warning.

## Security Checklist

Before deploying to production:

- [ ] Update all default passwords
- [ ] Configure cert-manager with your email address
- [ ] Set up Let's Encrypt production issuer
- [ ] Enable mTLS for internal services
- [ ] Configure DNS for your domains
- [ ] Request and verify SSL certificates
- [ ] Set up Sealed Secrets controller
- [ ] Encrypt all secrets with kubeseal
- [ ] Enable network policies (optional)
- [ ] Set up RBAC policies
- [ ] Configure security scanning
- [ ] Enable audit logging
- [ ] Review and harden configurations

## Compliance & Standards

### Transport Security
- **TLS 1.2+**: Enforced for all external connections
- **Strong Ciphers**: Modern cipher suites only
- **HSTS**: HTTP Strict Transport Security (recommended)

### Certificate Management
- **Automated Renewal**: Prevents expired certificates
- **90-day validity**: Let's Encrypt standard
- **15-day renewal window**: Certificates renewed before expiration

### Access Control
- **Kubernetes RBAC**: Role-based access control
- **Namespace Isolation**: Separate namespaces per environment
- **Service Accounts**: Dedicated accounts per service

## Monitoring & Auditing

### Certificate Monitoring
```bash
# Check certificate status
kubectl get certificate -A

# View certificate details
kubectl describe certificate <name> -n <namespace>
```

### Security Events
- Istio access logs (enabled by default)
- cert-manager events
- Kubernetes audit logs (cluster-dependent)

### Alerts
Consider setting up alerts for:
- Certificate expiration approaching
- Failed certificate renewals
- Unauthorized access attempts
- Unusual traffic patterns

## Security Updates

### Regular Maintenance
- Update Istio to latest stable version
- Update cert-manager for security patches
- Update Kubernetes to supported versions
- Scan container images for vulnerabilities

### Vulnerability Scanning
The CI pipeline includes Trivy security scanning:
- Scans Kubernetes manifests
- Checks for misconfigurations
- Identifies security issues

## Resources

- [cert-manager Documentation](../components/cert-manager.md)
- [Istio Security](../components/istio.md)
- [Sealed Secrets Guide](./sealed-secrets.md)
- [Best Practices](./best-practices.md)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/security-best-practices/)
- [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-ten/)

## Support

For security issues:
1. Review documentation in the `docs/security/` directory
2. Check component-specific documentation
3. Consult official project documentation
4. Open an issue in the repository (for non-sensitive issues)
