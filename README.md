# Docker Distroless Base Image

Minimal, secure distroless base image built from scratch. **1.24MB** total size.

## Features

- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface

## Quick Start

```bash
# Build
./scripts/build.sh 0.1.0

# Push to GitHub Container Registry
export GITHUB_TOKEN=your_token
./scripts/publish.sh 0.1.0 your-username

# Use in Dockerfile
FROM ghcr.io/your-username/distroless-base:0.1.0
COPY --chown=1000:1000 myapp /app/myapp
ENTRYPOINT ["/app/myapp"]
```

## Image Contents

- `/etc/ssl/certs/` - CA certificates for TLS/SSL
- `/usr/share/zoneinfo/` - Timezone database
- `/etc/passwd`, `/etc/group` - Non-root user config (app:1000)
- Environment: `PATH`, `HOME=/home/app`, `USER=app`, `TZ=UTC`

## Comparison

| Image | Size | Distroless | Rootless | Use Case |
|-------|------|------------|----------|----------|
| **This Image** | **1.24MB** | ✅ | ✅ | Production, security-critical |
| Alpine | ~5MB | ❌ | ❌ | Development, debugging |
| Debian Slim | ~70MB | ❌ | ❌ | Complex dependencies |
| Google Distroless | ~2-20MB | ✅ | ✅ | Language-specific |

## Scripts

- `build.sh [VERSION]` - Build image locally
- `publish.sh [VERSION] [NAMESPACE]` - Push to ghcr.io

## License

[MIT](LICENSE)