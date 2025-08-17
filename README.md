# Awesome Distroless

Minimal, secure distroless Docker images built from scratch. Each service is self-contained and immediately deployable.

All images use Debian 13 (trixie) in the build stage for the latest security patches and stable package versions, then deploy to our minimal distroless base image for maximum security.

## Why Distroless?

Traditional container images include entire operating systems with hundreds of packages you'll never use. Every binary is a potential security risk. Distroless changes this completely.

**What's NOT in a distroless image:**
- ❌ No shell (`sh`, `bash`) - Can't spawn interactive shells
- ❌ No coreutils (`ls`, `cat`, `echo`, `mkdir`, `rm`) - Can't manipulate files
- ❌ No package manager (`apt`, `yum`, `apk`) - Can't install software
- ❌ No text editors (`vi`, `nano`) - Can't modify configs
- ❌ No network tools (`ping`, `netstat`, `ss`) - Can't probe network
- ❌ No process tools (`ps`, `top`, `kill`) - Can't inspect processes
- ❌ No system libraries beyond the absolute minimum

**Result:** Your application is the ONLY executable in the container. An attacker who gains access has no tools to establish persistence, explore the system, or download malware.

## 🚀 Automated Image Publishing

Images are automatically built and published to GitHub Container Registry (GHCR) using GitHub workflows:

- **Automatic builds** on every push to main branch
- **Multi-architecture support** (linux/amd64, linux/arm64)
- **Vulnerability scanning** with Trivy for HIGH/CRITICAL security issues
- **Weekly security scans** to monitor for new vulnerabilities

**Available images:**
```bash
docker pull ghcr.io/cougz/awesome-distroless/postgres:17.5
docker pull ghcr.io/cougz/awesome-distroless/nginx:1.29.1
docker pull ghcr.io/cougz/awesome-distroless/redis:7.4.2
```

**Quick start:**
```bash
git clone https://github.com/cougz/awesome-distroless.git
cd awesome-distroless
docker compose --profile image up  # Uses pre-built images
```

## License

[MIT](LICENSE)