# Docker Distroless Images

Minimal, secure distroless images built from scratch with a modern configuration-driven tool manager. Base image **1.53MB**, with optional tools.

## Features

- **Configuration-Driven**: Zero-touch tool addition via YAML configs
- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface
- **Auto-Discovery**: Tools automatically detected and validated
- **Self-Documenting**: YAML configurations serve as documentation

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

## Quick Start

```bash
# Build base image
./scripts/build.sh 0.2.0

# Build with specific tools  
./scripts/build.sh 0.2.0 curl
./scripts/build.sh 0.2.0 jq

# Multiple tools (uses legacy system)
./scripts/build.sh 0.2.0 "curl,jq"

# Push to GitHub Container Registry
export GITHUB_TOKEN=your_token
./scripts/publish.sh distroless-base:0.2.0 your-username
./scripts/publish.sh distroless-curl:0.2.0 your-username

# Use in Dockerfile
FROM ghcr.io/your-username/distroless-base:0.2.0
COPY --chown=1000:1000 myapp /app/myapp
ENTRYPOINT ["/app/myapp"]
```

## Modern Tool Manager

The new tool manager provides a clean interface for managing tools:

```bash
# List all available tools
./scripts/tool-manager.sh list

# Build a specific tool
./scripts/tool-manager.sh build curl 0.2.0

# Test a tool
./scripts/tool-manager.sh test curl 0.2.0

# Show tool configuration
./scripts/tool-manager.sh config git

# Help
./scripts/tool-manager.sh help
```

### Available Tools

**Utilities:**
- `curl` (v8.11.1) - HTTPS-enabled HTTP client
- `jq` (latest) - JSON processor

**Development Tools:**
- `git` (v2.50.1) - Version control system  
- `go` (v1.24.6) - Go programming language
- `node` (v24.5.0) - Node.js runtime with npm

### Tool Categories
- **utility**: General-purpose utilities like curl, jq
- **development**: Development tools like git, go, node

## Development Workflow

The development tool images enable secure build environments:

```bash
# Clone and build a Go application
docker run --rm -v $(pwd):/workspace -w /workspace \
  distroless-git:0.2.0 \
  git clone https://github.com/your-org/your-app.git

# Build a Node.js application  
docker run --rm -v $(pwd)/your-app:/workspace -w /workspace \
  distroless-node:0.2.0 \
  node -e "console.log('Building app...')"

# Compile a Go binary
docker run --rm -v $(pwd)/your-app:/workspace -w /workspace \
  distroless-go:0.2.0 \
  go build -o app ./cmd/main.go
```

## Image Contents

- `/etc/ssl/certs/` - CA certificates for TLS/SSL
- `/usr/share/zoneinfo/` - Timezone database
- `/etc/passwd`, `/etc/group` - Non-root user config (app:1000)
- Environment: `PATH`, `HOME=/home/app`, `USER=app`, `TZ=UTC`

## Configuration System

Tools are defined in YAML configuration files in `tools/config/`:

### Example Tool Configuration

```yaml
# tools/config/curl.yml
name: curl
version: "8.11.1"
description: "HTTPS-enabled HTTP client"
category: "utility"
build:
  type: "source"
  url: "https://curl.se/download/curl-{version}.tar.gz"
  configure_flags:
    - "--disable-shared"
    - "--enable-static"
    - "--with-openssl"
  build_dependencies:
    - "build-essential"
    - "libssl-dev"
    - "wget"
  runtime_libraries:
    - "/lib/x86_64-linux-gnu/libssl.so.3"
    - "/lib/x86_64-linux-gnu/libcrypto.so.3"
  binary_path: "/tmp/curl"
  install_path: "/usr/local/bin/curl"
  test_command: "curl --version"
```

### Adding New Tools

1. **Create YAML config** in `tools/config/newtool.yml`:
   ```yaml
   name: newtool
   version: "1.0.0"
   description: "Description of your tool"
   category: "utility"  # or "development"
   build:
     type: "download"  # or "source"
     url: "https://example.com/newtool-{version}.tar.gz"
     build_dependencies:
       - "wget"
       - "ca-certificates"
     runtime_libraries: []
     binary_path: "/tmp/newtool"
     install_path: "/usr/local/bin/newtool"
     test_command: "newtool --version"
   ```

2. **Test the tool**:
   ```bash
   ./scripts/tool-manager.sh build newtool 0.2.0
   ./scripts/tool-manager.sh test newtool 0.2.0
   ```

3. **No code changes needed** - The tool is automatically discovered!

## Common Use Cases

```bash
# HTTP client with JSON processing (legacy multi-tool)
./scripts/build.sh 0.2.0 "curl,jq"
docker run --rm distroless-curl-jq:0.2.0 curl -s https://api.github.com/zen

# Simple health checker  
./scripts/build.sh 0.2.0 curl
docker run --rm distroless-curl:0.2.0 curl -f https://example.com/health

# Development environment for Go applications
./scripts/build.sh 0.2.0 go
docker run --rm -v $(pwd):/workspace distroless-go:0.2.0 go version

# JSON processing
./scripts/build.sh 0.2.0 jq
echo '{"name":"test"}' | docker run --rm -i distroless-jq:0.2.0 jq '.name'
```

## Image Naming

- **Base image**: `distroless-base:0.2.0`
- **Single tools**: `distroless-{tool}:0.2.0` (e.g., `distroless-curl:0.2.0`)
- **Multiple tools**: `distroless-{tool1}-{tool2}:0.2.0` (alphabetically sorted, legacy system)

## Comparison

| Image | Size | Distroless | Rootless | Config-Driven |
|-------|------|------------|----------|---------------|
| **Base Image** | **1.53MB** | ✅ | ✅ | ✅ |
| **With Tools** | **~5-20MB** | ✅ | ✅ | ✅ |
| Alpine | ~5MB | ❌ | ❌ | ❌ |
| Debian Slim | ~70MB | ❌ | ❌ | ❌ |
| Google Distroless | ~2-20MB | ✅ | ✅ | ❌ |
| Node Official | ~400MB | ❌ | ❌ | ❌ |

## Scripts & Commands

### Build Scripts
- `build.sh [VERSION] [TOOLS]` - Build images (backward compatible)
- `tool-manager.sh <command> [args]` - Modern tool management

### Tool Manager Commands
- `list` - List all available tools with details
- `build <tool> [version]` - Build specific tool image  
- `test <tool> [version]` - Test tool functionality
- `config <tool>` - Show tool configuration
- `help` - Show usage information

### Publishing
- `publish.sh <IMAGE_TAG> [NAMESPACE] [REGISTRY]` - Push to registry

## Dependencies

- **Docker** - Container runtime
- **yq** - YAML processor (automatically installed by tool manager)

## Architecture

```
docker-distroless/
├── scripts/
│   ├── build.sh              # Main build script (backward compatible)
│   ├── tool-manager.sh       # Modern tool manager
│   └── publish.sh           # Registry publishing
├── tools/
│   └── config/              # Tool configurations
│       ├── curl.yml
│       ├── jq.yml
│       ├── git.yml
│       ├── go.yml
│       └── node.yml
├── Dockerfile               # Base distroless image
└── README.md
```

## Migration from v0.1.x

The new system maintains full backward compatibility:

```bash
# Old way (still works)
./scripts/build.sh 0.2.0 curl

# New way (recommended)  
./scripts/tool-manager.sh build curl 0.2.0

# Multi-tools (temporarily uses legacy system)
./scripts/build.sh 0.2.0 "curl,jq"
```

## Contributing

1. Fork the repository
2. Add your tool configuration in `tools/config/yourtool.yml`
3. Test with `./scripts/tool-manager.sh build yourtool 0.2.0`
4. Submit a pull request

No code changes needed - just configuration!

## License

[MIT](LICENSE)