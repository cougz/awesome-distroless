# Security Policy

## 🔒 Security Overview

This repository contains distroless Docker images designed with security as a primary concern. We take security vulnerabilities seriously and have implemented comprehensive scanning and monitoring processes.

## 🛡️ Security Features

### Distroless Architecture
- **Minimal attack surface**: No shell, package managers, or unnecessary utilities
- **Reduced vulnerabilities**: Only essential runtime dependencies included
- **Non-root execution**: All containers run as non-privileged users (UID 1000)
- **Read-only filesystems**: Containers use read-only root filesystems where possible

### Security Hardening
- **Capability dropping**: All unnecessary Linux capabilities are dropped
- **No new privileges**: Containers cannot escalate privileges
- **Temporary filesystems**: Writable directories use tmpfs with size limits
- **Security options**: Additional security constraints applied

## 🔍 Vulnerability Scanning

### Automated Scanning
We run comprehensive security scans using multiple tools:

- **[Trivy](https://trivy.dev/)**: Primary vulnerability scanner
- **[Grype](https://github.com/anchore/grype)**: Secondary vulnerability scanner  
- **[Docker Scout](https://docs.docker.com/scout/)**: Docker's security analysis
- **[Syft](https://github.com/anchore/syft)**: Software Bill of Materials (SBOM) generation

### Scan Frequency
- **Daily scans**: Automated vulnerability scanning at 2 AM UTC
- **On-demand scans**: Manual workflow dispatch available
- **PR scans**: Security scans run on all pull requests
- **Push scans**: Scans triggered when Dockerfiles are modified

### Vulnerability Thresholds
| Severity | Threshold | Action |
|----------|-----------|---------|
| **Critical** | 0 | ❌ Fail build, create security issue |
| **High** | No limit | ⚠️ Report but allow |
| **Medium** | No limit | ℹ️ Report for awareness |
| **Low** | No limit | ℹ️ Report for awareness |

## 📊 Security Reports

### Accessing Reports
1. **GitHub Security Tab**: View vulnerability details at `/security/code-scanning`
2. **Workflow Artifacts**: Download detailed reports from workflow runs
3. **SBOM Files**: Software Bill of Materials available as artifacts

### Report Contents
- **SARIF files**: Security Analysis Results Interchange Format
- **JSON reports**: Detailed vulnerability information
- **SBOM files**: Complete software inventory (SPDX format)

## 🚨 Reporting Security Vulnerabilities

### Supported Versions
We provide security updates for the following versions:

| Version | Supported |
|---------|-----------|
| Latest (main branch) | ✅ |
| Previous major versions | ❌ |

### How to Report
If you discover a security vulnerability in our images:

1. **🔒 Private Disclosure**: Please do NOT create a public issue
2. **📧 Contact**: Report via [GitHub Security Advisories](https://github.com/cougz/awesome-distroless/security/advisories/new)
3. **📝 Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected images/versions
   - Impact assessment

### Response Timeline
- **Acknowledgment**: Within 24 hours
- **Initial assessment**: Within 72 hours  
- **Fix timeline**: Depends on severity
  - Critical: 1-3 days
  - High: 1-7 days
  - Medium: 2-4 weeks
  - Low: Next major release

## 🔧 Security Best Practices

### For Users
When using these images:

1. **Always use specific tags**: Avoid `latest` in production
2. **Enable read-only mode**: Use `read_only: true` in Docker Compose
3. **Drop capabilities**: Add `cap_drop: [ALL]` to your containers
4. **Use security options**: Apply `no-new-privileges:true`
5. **Limit resources**: Set memory and CPU limits
6. **Network isolation**: Use custom networks, not default bridge
7. **Secrets management**: Never include secrets in images

### Example Secure Configuration
```yaml
services:
  postgres:
    image: ghcr.io/cougz/awesome-distroless/postgres:17.5
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

## 🔄 Security Updates

### Automated Updates
- **Dependency monitoring**: Daily checks for upstream updates
- **Automated rebuilds**: Images rebuilt when base dependencies update
- **Security patches**: Critical vulnerabilities trigger immediate rebuilds

### Update Notifications
- **GitHub Issues**: Automated issues created for available updates
- **Security Advisories**: Published for confirmed vulnerabilities
- **Release Notes**: Security changes documented in releases

## 🏷️ Security Labels

We use the following labels for security-related issues:

- `security`: General security-related issues
- `vulnerability`: Confirmed security vulnerabilities  
- `high-priority`: Critical or high-severity security issues
- `dependencies`: Dependency-related security updates

## 📚 Additional Resources

### Documentation
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)

### Security Tools
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Grype Documentation](https://github.com/anchore/grype#grype)
- [Docker Scout](https://docs.docker.com/scout/)

### Compliance
Our images are designed to help with:
- **SOC 2** compliance requirements
- **ISO 27001** security standards
- **PCI DSS** container security
- **GDPR** data protection (minimal data exposure)

## 🤝 Security Community

We welcome security contributions:

1. **Security reviews**: Help review Dockerfiles and configurations
2. **Tool suggestions**: Recommend new security scanning tools
3. **Best practices**: Share security hardening techniques
4. **Vulnerability research**: Responsible disclosure of issues

---

**Last Updated**: Auto-updated by security workflows
**Next Review**: Quarterly security policy review