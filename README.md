# Docker Distroless Images

Minimal, secure distroless images built from scratch. Base image **1.53MB**, with optional tools.

## Features

- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface

## Quick Start

```bash
# Build base image
./scripts/build.sh 0.5.0

# Build with tools  
./scripts/build.sh 0.5.0 curl
./scripts/build.sh 0.5.0 "curl,jq"

# Push to GitHub Container Registry
export GITHUB_TOKEN=your_token
./scripts/publish.sh distroless-base:0.5.0 your-username
./scripts/publish.sh distroless-curl:0.5.0 your-username

# Use in Dockerfile
FROM ghcr.io/your-username/distroless-base:0.5.0
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
| **This Image** | **1.53MB** | ✅ | ✅ | Production, security-critical |
| Alpine | ~5MB | ❌ | ❌ | Development, debugging |
| Debian Slim | ~70MB | ❌ | ❌ | Complex dependencies |
| Google Distroless | ~2-20MB | ✅ | ✅ | Language-specific |

## Tools Support

You can extend the base image with additional tools for specific use cases:

```bash
# Build base image only
./scripts/build.sh 0.5.0

# Build with curl (HTTPS enabled)
./scripts/build.sh 0.5.0 curl

# Build with multiple tools
./scripts/build.sh 0.5.0 "curl,jq"
```

### Available Tools

- `curl`
- `jq`

### Common Use Cases

```bash
# API monitoring container
./scripts/build.sh 0.5.0 "curl,jq"
docker run --rm distroless-curl-jq:0.5.0 curl -s https://api.github.com/zen

# Simple health checker  
./scripts/build.sh 0.5.0 curl
docker run --rm distroless-curl:0.5.0 curl -f https://example.com/health
```

### Adding New Tools

1. Create `tools/newtool.Dockerfile` following the pattern
2. Add build logic to `scripts/build.sh` (in the case statements)  
3. Test: `./scripts/build.sh 0.5.0 newtool`

### Image Naming

- Base image: `distroless-base:0.5.0`
- With curl: `distroless-curl:0.5.0` 
- With jq: `distroless-jq:0.5.0`
- With multiple tools: `distroless-curl-jq:0.5.0` (alphabetically sorted)

## Scripts

- `build.sh [VERSION] [TOOLS]` - Build images locally
- `publish.sh <IMAGE_TAG> [NAMESPACE] [REGISTRY]` - Push to registry

## License

[MIT](LICENSE)