# Docker Distroless Images

Minimal, secure distroless images built from scratch with a modern 3-tier architecture. Base image **1.53MB**, with configurable tools and applications.

## Features

- **3-Tier Architecture**: Base → Tools → Applications
- **Configuration-Driven**: Zero-touch addition via YAML configs
- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface
- **Auto-Discovery**: Tools and apps automatically detected
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

**Result:** Your application is the ONLY executable in the container. An attacker who gains access has no tools to establish persistence, explore the system, or download malware.

## Architecture

### 3-Tier Management System

```
┌─────────────────────────────────────────┐
│           Applications Layer            │
│         (app-manager.sh)                │
│   • pocket-id, custom apps              │
│   • Multi-stage builds using tools      │
│   • Docker Compose orchestration        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│            Tools Layer                  │
│         (tool-manager.sh)               │
│   • curl, jq, git, go, node, postgres   │
│   • Built on base image                 │
│   • Single-purpose tool images          │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│             Base Layer                  │
│         (base-manager.sh)               │
│   • Minimal distroless foundation       │
│   • CA certs, timezone, user setup      │
│   • 1.53MB from scratch                 │
└─────────────────────────────────────────┘
```

### Project Structure

```
docker-distroless/
├── scripts/
│   ├── base-manager.sh      # Base image management
│   ├── tool-manager.sh      # Tool images management
│   ├── app-manager.sh       # Application management
│   └── build.sh            # Legacy compatibility
├── tools/
│   ├── config/             # Tool build configurations
│   │   ├── curl.yml
│   │   ├── git.yml
│   │   ├── go.yml
│   │   ├── jq.yml
│   │   ├── node.yml
│   │   └── postgres.yml
│   └── dockerfiles/        # Generated tool Dockerfiles
├── apps/
│   ├── config/             # App build configurations
│   │   └── pocket-id.yml
│   ├── dockerfiles/        # App Dockerfiles
│   │   └── pocket-id.Dockerfile
│   └── compose/            # Docker Compose files
│       └── pocket-id.yml
├── Dockerfile              # Base distroless image
└── README.md
```

## Quick Start

### Building the Stack

```bash
# 1. Build base image
./scripts/base-manager.sh build

# 2. Build required tools
./scripts/tool-manager.sh build curl
./scripts/tool-manager.sh build node
./scripts/tool-manager.sh build go
./scripts/tool-manager.sh build postgres

# 3. Build application
./scripts/app-manager.sh build pocket-id

# 4. Deploy with Docker Compose
docker compose -f apps/compose/pocket-id.yml up -d

# Access the application
curl http://localhost:3000
```

## Base Manager

Manages the foundational distroless image:

```bash
# Build base image
./scripts/base-manager.sh build [VERSION]

# Test base image
./scripts/base-manager.sh test

# Show base image details
./scripts/base-manager.sh list

# Clean base images
./scripts/base-manager.sh clean
```

## Tool Manager

Manages individual tool images built on the base:

```bash
# List all available tools
./scripts/tool-manager.sh list

# Build a specific tool
./scripts/tool-manager.sh build curl

# Test a tool
./scripts/tool-manager.sh test curl

# Show tool configuration
./scripts/tool-manager.sh show curl

# Show tool Dockerfile
./scripts/tool-manager.sh show-dockerfile curl

# Clean tool images
./scripts/tool-manager.sh clean [TOOL]
```

### Available Tools

| Tool | Category | Description | Size |
|------|----------|-------------|------|
| `curl` | utility | HTTPS-enabled HTTP client | ~8MB |
| `jq` | utility | JSON processor | ~5MB |
| `git` | development | Version control system | ~45MB |
| `go` | development | Go programming language | ~120MB |
| `node` | development | Node.js runtime with npm | ~85MB |
| `postgres` | database | PostgreSQL server with defaults | ~80MB |

## Application Manager

Manages complete applications using multi-stage builds:

```bash
# List available applications
./scripts/app-manager.sh list

# Build application image
./scripts/app-manager.sh build pocket-id

# Test application
./scripts/app-manager.sh test pocket-id

# Generate Docker Compose file
./scripts/app-manager.sh compose pocket-id

# Show application config
./scripts/app-manager.sh show pocket-id

# Clean application images
./scripts/app-manager.sh clean [APP]
```

### Example Application: Pocket-ID

Pocket-ID is a self-hosted authentication service built from source using our distroless stack:

```bash
# Build the complete stack
./scripts/app-manager.sh build pocket-id

# Deploy with Docker Compose
docker compose -f apps/compose/pocket-id.yml up -d

# Access at http://localhost:3000
```

**Stack Components:**
- **distroless-pocket-id**: 60MB application image
- **distroless-postgres**: 80MB database image
- **Total Stack**: ~140MB (vs ~1GB with traditional images)

## Adding New Tools

1. **Create YAML config** in `tools/config/newtool.yml`:
   ```yaml
   name: newtool
   version: "1.0.0"
   description: "Tool description"
   category: "utility"
   build:
     type: "source"  # or "download"
     url: "https://example.com/newtool-{version}.tar.gz"
     configure_flags:
       - "--enable-feature"
     build_dependencies:
       - "build-essential"
       - "libssl-dev"
     runtime_libraries:
       - "/lib/x86_64-linux-gnu/libssl.so.3"
     binary_path: "/tmp/newtool/bin"
     install_path: "/usr/local/bin"
     test_command: "newtool --version"
   ```

2. **Build and test**:
   ```bash
   ./scripts/tool-manager.sh build newtool
   ./scripts/tool-manager.sh test newtool
   ```

## Adding New Applications

1. **Create app config** in `apps/config/myapp.yml`:
   ```yaml
   name: myapp
   description: "Application description"
   category: "application"
   build:
     tools_required:
       - node:24.5.0
       - postgres
   defaults:
     port: 8080
     data_dir: "/app/data"
   ```

2. **Create Dockerfile** in `apps/dockerfiles/myapp.Dockerfile`:
   ```dockerfile
   # Multi-stage build using tool images
   FROM distroless-node AS builder
   # Build steps...
   
   FROM distroless-base:0.2.0
   # Copy built application
   # Runtime configuration
   ```

3. **Create compose file** in `apps/compose/myapp.yml`:
   ```yaml
   services:
     app:
       image: distroless-myapp
       ports:
         - "8080:8080"
   ```

4. **Build and deploy**:
   ```bash
   ./scripts/app-manager.sh build myapp
   docker compose -f apps/compose/myapp.yml up -d
   ```

## PostgreSQL Special Features

The PostgreSQL tool includes zero-configuration defaults:
- **User**: postgres
- **Password**: postgres  
- **Database**: postgres
- **Port**: 5432
- **Data Directory**: /var/lib/postgresql/data

Pre-initialized and ready to use:
```bash
# Run PostgreSQL
docker run -p 5432:5432 distroless-postgres

# Connect from another container
psql -h database -U postgres -d postgres
```

## Comparison

| Image Type | Size | Distroless | Rootless | Config-Driven | Multi-stage |
|------------|------|------------|----------|---------------|-------------|
| **Base Image** | **1.53MB** | ✅ | ✅ | ✅ | N/A |
| **Tool Images** | **5-120MB** | ✅ | ✅ | ✅ | ✅ |
| **App Images** | **20-100MB** | ✅ | ✅ | ✅ | ✅ |
| Alpine | ~5MB | ❌ | ❌ | ❌ | ❌ |
| Debian Slim | ~70MB | ❌ | ❌ | ❌ | ❌ |
| Ubuntu | ~80MB | ❌ | ❌ | ❌ | ❌ |
| Node Official | ~400MB | ❌ | ❌ | ❌ | ❌ |

## Security Benefits

1. **No Shell Access**: Attackers can't execute commands
2. **No Package Manager**: Can't install malicious software
3. **No System Utilities**: Can't explore or modify the system
4. **Minimal Libraries**: Reduced attack surface
5. **Non-root by Default**: Limited privileges (UID 1000)
6. **Immutable Runtime**: No writable system directories

## Dependencies

- **Docker** - Container runtime
- **yq** - YAML processor (auto-installed if missing)
- **Standard build tools** - For compiling from source

## Important Notes

- **No hardcoded dependencies between manager scripts** - Each operates independently
- **Tools require base image** - Build base first
- **Apps require tool images** - Build required tools before apps
- **Compose files** are in `apps/compose/` not root directory
- **Configuration-driven** - Add new tools/apps via YAML only

## Contributing

1. Fork the repository
2. Add configurations in appropriate directories:
   - Tools: `tools/config/yourtool.yml`
   - Apps: `apps/config/yourapp.yml`
3. Test thoroughly:
   ```bash
   ./scripts/tool-manager.sh build yourtool
   ./scripts/tool-manager.sh test yourtool
   ```
4. Submit a pull request

No code changes needed for new tools - just configuration!

## License

[MIT](LICENSE)