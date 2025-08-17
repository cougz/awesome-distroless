# Distroless Base Image

The foundation image for all distroless services. Built from scratch with minimal dependencies.

## Features

- **Ultra-minimal**: Built from scratch, only 854KB
- **Secure**: No shell, no package manager, certificates included
- **DNS resolution**: Includes nsswitch.conf for proper name resolution
- **Latest packages**: Built with Debian 13 (trixie) for security patches

## Build Configuration

Copy `.env.example` to `.env` to customize build (only used when building locally):

| Variable | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.0.0` | Base image version |
| `APP_UID` | `1000` | User ID for app user |
| `APP_GID` | `1000` | Group ID for app user |
| `TZ` | `UTC` | Timezone |

## Build

```bash
docker compose build
```

## Used By

All other services in this repository inherit from this base image:
- PostgreSQL
- Nginx  
- Redis
- Testing utilities (curl, git, go, node)