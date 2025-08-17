# Distroless Base Image

The foundation image for all distroless services. Built from scratch with minimal dependencies.

## Features

- **Ultra-minimal**: Built from scratch, only 854KB
- **Configurable**: UID/GID, timezone via build args
- **Security**: No shell, no package manager, certificates included
- **DNS resolution**: Includes nsswitch.conf for proper name resolution

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.0.0` | Base image version |
| `APP_UID` | `1000` | User ID for app user |
| `APP_GID` | `1000` | Group ID for app user |
| `TZ` | `UTC` | Timezone |

## Build

```bash
docker compose build
```

## Contents

- CA certificates for HTTPS
- Timezone data
- Minimal user/group configuration
- DNS resolution configuration
- No shell or package manager

## Used By

All other services in this repository inherit from this base image:
- PostgreSQL
- Nginx  
- Redis
- Testing utilities (curl, git, go, node)

## Size Comparison

- scratch: 0 bytes
- distroless-base: 854KB
- alpine:latest: ~5MB
- debian:trixie-slim: ~74MB

## Security

- No shell access
- No package manager
- Minimal attack surface
- Non-root user by default
- Root certificates included