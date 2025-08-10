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
- `curl` - HTTPS-enabled HTTP client
- `jq` - JSON processor

**Development Tools:**
- `git` - Version control system  
- `go` - Go programming language
- `node` - Node.js runtime with npm

**Database:**
- `postgres` - PostgreSQL database server with complete toolset

### Tool Categories
- **utility**: General-purpose utilities like curl, jq
- **development**: Development tools like git, go, node
- **database**: Database servers like postgres

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
│       ├── node.yml
│       └── postgres.yml
├── Dockerfile               # Base distroless image
└── README.md
```

## Contributing

1. Fork the repository
2. Add your tool configuration in `tools/config/yourtool.yml`
3. Test with `./scripts/tool-manager.sh build yourtool 0.2.0`
4. Submit a pull request

No code changes needed - just configuration!

## License

[MIT](LICENSE)