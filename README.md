# Docker Distroless Images

Minimal, secure distroless images built from scratch. Base image **1.53MB**, with optional tools.

## Features

- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface

## Why Use Distroless?

Traditional container images include entire operating systems with hundreds of packages you'll never use. Every binary is a potential security risk. Distroless changes this completely.

**What's NOT in a distroless image:**
- ❌ No shell (`sh`, `bash`) - Can't spawn interactive shells
- ❌ No coreutils (`ls`, `cat`, `echo`, `mkdir`, `rm`) - Can't manipulate files
- ❌ No package manager (`apt`, `yum`, `apk`) - Can't install software
- ❌ No text editors (`vi`, `nano`) - Can't modify configs
- ❌ No network tools (`ping`, `netstat`, `ss`) - Can't probe network
- ❌ No process tools (`ps`, `top`, `kill`) - Can't inspect processes
- ❌ No system libraries beyond the absolute minimum

**Result:** Your application is the ONLY executable in the container. An attacker who gains access has no tools to establish persistence, explore the system, or download malware. They can't even list files without your application's help.

## Development Workflow

The development tool images enable secure build environments while maintaining distroless principles:

```bash
# Clone, build, and package a Go application
docker run --rm -v $(pwd):/workspace -w /workspace \
  distroless-git-go-node:0.2.0 \
  git clone https://github.com/your-org/your-app.git

# Build a Node.js application  
docker run --rm -v $(pwd)/your-app:/workspace -w /workspace \
  distroless-git-go-node:0.2.0 \
  node -e "console.log('npm install would run here')"

# Compile a Go binary
docker run --rm -v $(pwd)/your-app:/workspace -w /workspace \
  distroless-git-go-node:0.2.0 \
  go build -o app ./cmd/main.go
```

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

| Image | Size | Distroless | Rootless |
|-------|------|------------|----------|
| **Base Image** | **1.53MB** | ✅ | ✅ |
| **With Dev Tools** | **~485MB** | ✅ | ✅ |
| Alpine | ~5MB | ❌ | ❌ |
| Debian Slim | ~70MB | ❌ | ❌ |
| Google Distroless | ~2-20MB | ✅ | ✅ |
| Node Official | ~400MB | ❌ | ❌ |

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

**Utilities:**
- `curl` - HTTPS-enabled HTTP client
- `jq` - JSON processor

**Development Tools:**
- `git` (v2.50.1) - Version control system
- `go` (v1.24.6) - Go programming language
- `node` (v24.5.0) - Node.js runtime with npm

### Common Use Cases

```bash
# HTTP client with JSON processing
./scripts/build.sh 0.5.0 "curl,jq"
docker run --rm distroless-curl-jq:0.5.0 curl -s https://api.github.com/zen

# Simple health checker  
./scripts/build.sh 0.5.0 curl
docker run --rm distroless-curl:0.5.0 curl -f https://example.com/health

# Development environment for Go applications
./scripts/build.sh 0.5.0 "git,go"
docker run --rm -v $(pwd):/workspace distroless-git-go:0.5.0 go version

# Full development stack for Node.js projects
./scripts/build.sh 0.5.0 "git,go,node"
docker run --rm -v $(pwd):/workspace distroless-git-go-node:0.5.0 node --version

# Build and containerize applications
./scripts/build.sh 0.5.0 "git,go,node"
# Use the image to clone, build, and package your application
```

### Adding New Tools

1. Create `tools/newtool.Dockerfile` following the pattern
2. Add build logic to `scripts/build.sh` (in the case statements)  
3. Test: `./scripts/build.sh 0.5.0 newtool`

### Image Naming

- Base image: `distroless-base:0.5.0`
- With utilities: `distroless-curl:0.5.0`, `distroless-jq:0.5.0`
- With dev tools: `distroless-git:0.5.0`, `distroless-go:0.5.0`, `distroless-node:0.5.0`
- With multiple tools: `distroless-curl-jq:0.5.0`, `distroless-git-go-node:0.5.0` (alphabetically sorted)

## Scripts

- `build.sh [VERSION] [TOOLS]` - Build images locally
- `publish.sh <IMAGE_TAG> [NAMESPACE] [REGISTRY]` - Push to registry

## License

[MIT](LICENSE)