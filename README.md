# Docker Distroless Base Image

A minimal, secure distroless base image built from scratch for containerized applications.

## Features

- **Minimal Size**: Under 5MB total image size
- **Security First**: No shell, package manager, or unnecessary binaries
- **Rootless**: Runs as non-root user (UID 1000) by default
- **Essential Files Only**:
  - CA certificates for TLS/SSL verification
  - Timezone data for proper time handling
  - User/group configuration for proper permissions
- **Multi-Architecture**: Built for linux/amd64 platform

## Quick Start

### Building the Image

```bash
# Build with default version (0.1.0)
./scripts/build.sh

# Build with custom version
./scripts/build.sh 1.0.0

# Build with custom registry and namespace
./scripts/build.sh 1.0.0 ghcr.io myusername
```

### Publishing to GitHub Container Registry

```bash
# Set GitHub token (required for authentication)
export GITHUB_TOKEN=your_personal_access_token

# Publish with default version
./scripts/publish.sh

# Publish with custom version and namespace
./scripts/publish.sh 1.0.0 myusername
```

### Using as a Base Image

```dockerfile
# Use from GitHub Container Registry
FROM ghcr.io/yourusername/distroless-base:0.1.0

# Copy your application
COPY --chown=1000:1000 myapp /app/myapp

# Your application will run as non-root user (UID 1000)
ENTRYPOINT ["/app/myapp"]
```

## Image Contents

### Included Files

| Path | Purpose |
|------|---------|
| `/etc/ssl/certs/ca-certificates.crt` | Root CA certificates for TLS/SSL |
| `/usr/share/zoneinfo/` | Timezone database |
| `/etc/passwd` | User account information (app user) |
| `/etc/group` | Group information |
| `/etc/nsswitch.conf` | Name service switch configuration |

### Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `PATH` | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` | Standard PATH |
| `HOME` | `/home/app` | Home directory for app user |
| `USER` | `app` | Default username |
| `TZ` | `UTC` | Default timezone |
| `SSL_CERT_FILE` | `/etc/ssl/certs/ca-certificates.crt` | CA certificates location |

### User Configuration

- **User**: app
- **UID**: 1000
- **GID**: 1000
- **Home**: /home/app
- **Shell**: /sbin/nologin (no shell access)

## Security Considerations

### What's NOT Included

- No shell (`sh`, `bash`, etc.)
- No package managers (`apt`, `apk`, etc.)
- No system utilities (`ls`, `cat`, `ps`, etc.)
- No interpreters (Python, Node.js, etc.)
- No debugging tools
- No temporary files or caches

### Best Practices

1. **Always specify tags**: Use specific version tags instead of `latest` in production
2. **Scan for vulnerabilities**: Regular security scanning even though the attack surface is minimal
3. **Read-only filesystem**: Consider running containers with `--read-only` flag
4. **Drop capabilities**: Use `--cap-drop=ALL` when possible
5. **Resource limits**: Set memory and CPU limits

## Building Your Own Distroless Images

### Example: Go Application

```dockerfile
# Build stage
FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o myapp

# Runtime stage
FROM ghcr.io/yourusername/distroless-base:0.1.0
COPY --from=builder --chown=1000:1000 /app/myapp /app/myapp
ENTRYPOINT ["/app/myapp"]
```

### Example: Static Binary

```dockerfile
FROM ghcr.io/yourusername/distroless-base:0.1.0
COPY --chown=1000:1000 ./myapp /app/myapp
ENTRYPOINT ["/app/myapp"]
```

## Repository Structure

```
docker-distroless-base/
├── Dockerfile              # Multi-stage build definition
├── scripts/
│   ├── build.sh           # Build script with version support
│   └── publish.sh         # GitHub Container Registry publish script
├── .gitignore             # Git ignore rules
└── README.md              # This file
```

## Scripts

### build.sh

Builds the distroless base image locally with proper tagging.

**Usage:**
```bash
./scripts/build.sh [VERSION] [REGISTRY] [NAMESPACE]
```

**Features:**
- Multi-architecture build support
- Automatic tagging (version and latest)
- Size verification (warns if > 5MB)
- User configuration validation

### publish.sh

Publishes the image to GitHub Container Registry.

**Usage:**
```bash
export GITHUB_TOKEN=your_token
./scripts/publish.sh [VERSION] [NAMESPACE]
```

**Features:**
- Automatic authentication to ghcr.io
- Pushes both version and latest tags
- Build verification before push
- Clear error messages and guidance

## Development

### Prerequisites

- Docker 20.10+ or Docker Desktop
- Bash shell (for scripts)
- GitHub account (for publishing)
- Personal Access Token with `write:packages` scope

### Making Changes

1. Modify the `Dockerfile` as needed
2. Test locally with `./scripts/build.sh`
3. Update version in build arguments
4. Commit changes
5. Publish new version with `./scripts/publish.sh`

### Testing

Test your distroless base image:

```bash
# Build test image
./scripts/build.sh 0.1.0-test

# Verify size
docker images distroless-base:0.1.0-test

# Test with a simple binary
docker run --rm distroless-base:0.1.0-test /bin/true || echo "No shell (expected)"

# Inspect image layers
docker history distroless-base:0.1.0-test

# Check user configuration
docker inspect distroless-base:0.1.0-test | grep -A5 "User"
```

## Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible changes (file removals, structure changes)
- **MINOR**: New features (additional files, environment variables)
- **PATCH**: Bug fixes and minor updates

Current version: **0.1.0**

## Comparison with Alternatives

| Image | Size | Shell | Package Manager | Rootless | Use Case |
|-------|------|-------|-----------------|----------|----------|
| **This Image** | **1.24MB** | ❌ | ❌ | ✅ | Production, security-critical |
| Alpine | ~5MB | ✅ | ✅ | ❌ | Development, debugging needed |
| Debian Slim | ~70MB | ✅ | ✅ | ❌ | Complex dependencies |
| Ubuntu | ~70MB+ | ✅ | ✅ | ❌ | Full environment needed |
| Google Distroless | ~2-20MB | ❌ | ❌ | ✅ | Language-specific runtimes |

## Troubleshooting

### Image Too Large

If your image exceeds 5MB:
1. Check for unnecessary files in COPY commands
2. Verify Alpine package installations are minimal
3. Use `docker history` to identify large layers

### Authentication Issues

For GitHub Container Registry:
1. Create a Personal Access Token: https://github.com/settings/tokens
2. Enable `write:packages` and `delete:packages` scopes
3. Export as `GITHUB_TOKEN` or `CR_PAT`

### Build Failures

Common issues:
- Docker daemon not running
- Insufficient disk space
- Network issues downloading Alpine packages

### Runtime Issues

Since there's no shell:
- Use `docker cp` to extract files
- Debug in a development image first
- Use `strace` from host if needed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for use as a base image in containerized applications.

## Acknowledgments

Inspired by:
- [Google Distroless](https://github.com/GoogleContainerTools/distroless)
- Security best practices from OWASP
- Container optimization techniques from the Docker community

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Provide detailed reproduction steps for bugs