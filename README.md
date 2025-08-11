# Docker Distroless Images

Minimal, secure distroless images built from scratch with a modern 3-tier architecture. Base image **1.53MB**, with configurable tools and applications.

## Features

- **3-Tier Architecture**: Base → Tools → Applications
- **Configuration-Driven**: Zero-touch addition via YAML configs  
- **Version Validation**: Automated consistency checking
- **Rootless**: Runs as non-root user (UID 1000) by default
- **Distroless**: No shell, no package manager, no utilities
- **Minimal**: Only CA certificates, timezone data, and user config
- **Secure**: Smallest possible attack surface
- **Single Responsibility**: Each tool serves one purpose
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
│   • pocket-id:1.7.0, custom apps       │
│   • Multi-stage builds using tools      │
│   • Docker Compose orchestration        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│            Tools Layer                  │
│         (tool-manager.sh)               │
│   • git:2.50.1, go:1.24.6, node:24.5.0 │
│   • postgres:17.5, curl:8.11.1, jq:1.8.1│
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
│   ├── base-manager.sh        # Base image management
│   ├── tool-manager.sh        # Tool images management  
│   ├── app-manager.sh         # Application management
│   ├── validate-versions.sh   # Version consistency validation
│   └── build.sh              # Legacy compatibility
├── base/
│   ├── config/               # Base configuration
│   │   └── base.yml
│   └── dockerfiles/          # Base Dockerfiles
│       └── base.Dockerfile
├── tools/
│   ├── config/               # Tool configurations
│   │   ├── curl.yml
│   │   ├── git.yml
│   │   ├── go.yml
│   │   ├── jq.yml
│   │   ├── node.yml
│   │   └── postgres.yml
│   └── dockerfiles/          # Tool Dockerfiles
├── apps/
│   ├── config/               # App configurations
│   │   └── pocket-id.yml
│   ├── dockerfiles/          # App Dockerfiles
│   │   └── pocket-id.Dockerfile
│   └── compose/              # Docker Compose files
│       └── pocket-id.yml
└── README.md
```

## Quick Start

### Building the Stack

```bash
# 1. Build base image
./scripts/base-manager.sh build

# 2. Build required tool images (in dependency order)
./scripts/tool-manager.sh build git
./scripts/tool-manager.sh build node  
./scripts/tool-manager.sh build go
./scripts/tool-manager.sh build postgres

# 3. Build application image
./scripts/app-manager.sh build pocket-id

# 4. Verify all images were created
docker images | grep distroless

# 5. Deploy with Docker Compose
docker compose -f apps/compose/pocket-id.yml up -d

# Access the application
curl http://localhost:3000
```

### Version Validation

```bash
# Validate version consistency across configs and Dockerfiles
./scripts/validate-versions.sh
```

## Base Manager

Manages the foundational distroless image:

```bash
# Build base image (version from base/config/base.yml)
./scripts/base-manager.sh build

# Build specific version
./scripts/base-manager.sh build 1.0.0

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

# Build a specific tool (uses version from YAML config)
./scripts/tool-manager.sh build curl

# Test a tool
./scripts/tool-manager.sh test curl

# Show tool configuration
./scripts/tool-manager.sh config curl

# Show tool Dockerfile
./scripts/tool-manager.sh dockerfile curl
```

### Available Tools

| Tool | Version | Category | Description | Size |
|------|---------|----------|-------------|------|
| `curl` | 8.11.1 | utility | HTTPS-enabled HTTP client | ~8MB |
| `jq` | 1.8.1 | utility | JSON command-line processor | ~5MB |
| `git` | 2.50.1 | development | Version control system | ~45MB |
| `go` | 1.24.6 | development | Go programming language | ~120MB |
| `node` | 24.5.0 | development | Node.js runtime with npm | ~85MB |
| `postgres` | 17.5 | database | PostgreSQL with sensible defaults | ~80MB |

All versions are managed via YAML configurations and automatically validated for consistency.

## Application Manager

Manages complete applications using multi-stage builds:

```bash
# List available applications
./scripts/app-manager.sh list

# Build application image (uses version from YAML config)
./scripts/app-manager.sh build pocket-id

# Test application
./scripts/app-manager.sh test pocket-id

# Generate Docker Compose file
./scripts/app-manager.sh compose pocket-id

# Show application config
./scripts/app-manager.sh config pocket-id
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
- **distroless-pocket-id:1.7.0**: 60MB application image
- **distroless-postgres:17.5**: 80MB database image  
- **Total Stack**: ~140MB (vs ~1GB with traditional images)

## Adding New Tools

1. **Create YAML config** in `tools/config/newtool.yml`:
   ```yaml
   name: newtool
   version: "1.0.0"
   description: "Tool description"
   category: "utility"
   build:
     test_command: "newtool --version"
   ```

2. **Create Dockerfile** in `tools/dockerfiles/newtool.Dockerfile`:
   ```dockerfile
   FROM debian:trixie-slim AS tool-builder
   
   ARG TOOL_VERSION=1.0.0
   RUN wget -q "https://example.com/newtool-v${TOOL_VERSION}.tar.gz" -O /tmp/newtool.tar.gz
   # Build steps...
   
   FROM distroless-base:0.2.0
   COPY --from=tool-builder /tmp/newtool-install /usr/local/
   # Runtime configuration...
   ```

3. **Build and test**:
   ```bash
   ./scripts/tool-manager.sh build newtool
   ./scripts/tool-manager.sh test newtool
   ./scripts/validate-versions.sh  # Ensure consistency
   ```

## Adding New Applications

1. **Create app config** in `apps/config/myapp.yml`:
   ```yaml
   name: myapp
   version: "2.1.0"
   description: "Application description"
   category: "application"
   tools:
     - node
     - postgres
   ```

2. **Create Dockerfile** in `apps/dockerfiles/myapp.Dockerfile`:
   ```dockerfile
   # Multi-stage build using tool images
   FROM distroless-node:24.5.0 AS builder
   # Build steps...
   
   FROM distroless-base:0.2.0
   COPY --from=builder /app /app
   CMD ["/app/myapp"]
   ```

3. **Create compose file** in `apps/compose/myapp.yml`:
   ```yaml
   services:
     app:
       image: distroless-myapp:2.1.0
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
docker run -p 5432:5432 distroless-postgres:17.5

# Connect from another container
psql -h database -U postgres -d postgres
```

## Multi-Tool Usage

Use Docker Compose to combine tools when needed:

```yaml
# Instead of a single multi-tool container
services:
  frontend:
    image: distroless-node:24.5.0
    volumes:
      - .:/workspace
  backend:
    image: distroless-go:1.24.6  
    volumes:
      - .:/workspace
  git-ops:
    image: distroless-git:2.50.1
    volumes:
      - .:/workspace
```

This approach maintains single responsibility while providing flexibility.

## Comparison

| Image Type | Size | Distroless | Rootless | Versioned | Validated |
|------------|------|------------|----------|-----------|-----------|
| **Base Image** | **1.53MB** | ✅ | ✅ | ✅ | ✅ |
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
7. **Version Consistency**: Automated validation prevents drift

## Dependencies

- **Docker** - Container runtime
- **yq** - YAML processor for configuration parsing

## Important Notes

- **Config-driven approach** - Versions managed in YAML, build logic in Dockerfiles
- **Tools require base image** - Build base first (`./scripts/base-manager.sh build`)
- **Apps require tool images** - Build required tools before apps
- **Single responsibility** - Each tool serves one purpose, use Compose for multi-tool needs
- **Version validation** - Run `./scripts/validate-versions.sh` to ensure consistency
- **No hardcoded scripts** - All installation logic properly contained in Dockerfiles

## Contributing

1. Fork the repository
2. Add configurations in appropriate directories:
   - Tools: `tools/config/yourtool.yml` + `tools/dockerfiles/yourtool.Dockerfile`
   - Apps: `apps/config/yourapp.yml` + `apps/dockerfiles/yourapp.Dockerfile`
3. Test thoroughly:
   ```bash
   ./scripts/tool-manager.sh build yourtool
   ./scripts/tool-manager.sh test yourtool
   ./scripts/validate-versions.sh
   ```
4. Submit a pull request

Follow the config-driven approach: metadata in YAML, build logic in Dockerfiles!

## License

[MIT](LICENSE)