# Pocket-ID Distroless

Minimal, secure [Pocket-ID](https://github.com/pocket-id/pocket-id) authentication service in a distroless container.

## What is Pocket-ID?

Pocket-ID is a lightweight, self-hosted OAuth2 and OpenID Connect provider that simplifies authentication for your applications.

## Features

- **Distroless security**: No shell, package manager, or unnecessary utilities
- **Multi-architecture**: Supports linux/amd64 and linux/arm64
- **Security hardened**: Read-only filesystem, non-root user, dropped capabilities
- **Built from source**: Compiled from official Pocket-ID repository
- **Integrated database**: Includes PostgreSQL for complete stack
- **Built with Debian 13 (trixie)** for latest security patches

## Quick Start

### Option 1: Use Pre-built Images from Registry
```bash
# Copy environment file
cp .env.example .env

# Edit .env to use registry images (uncomment the image variables)
nano .env

# Start with registry images
docker compose up -d
```

### Option 2: Build from Source Locally
```bash
# Copy environment file  
cp .env.example .env

# Edit configuration as needed (keep image variables commented)
nano .env

# Build and start
docker compose up -d --build
```

### Option 3: Use Existing Local Images
```bash
# Copy environment file
cp .env.example .env

# Start with existing local images (no build)
docker compose up -d
```

## Configuration

### Environment Variables

**Build Configuration:**
- `APP_UID=1000` - User ID for container user
- `APP_GID=1000` - Group ID for container user  
- `TZ=UTC` - Timezone setting
- `POCKET_ID_VERSION=1.9.1` - Pocket-ID version to build

**Image Configuration (optional):**
- `POCKET_ID_IMAGE` - Override pocket-id image (e.g., `ghcr.io/cougz/awesome-distroless/pocket-id:1.9.1`)
- `POSTGRES_IMAGE` - Override postgres image (e.g., `ghcr.io/cougz/awesome-distroless/postgres:17.5`)
- `BASE_IMAGE` - Override base image for builds (default: `ghcr.io/cougz/awesome-distroless/base:1.0.0`)

**Runtime Configuration:**
- `WEB_PORT=3000` - Port to expose on host
- `POSTGRES_DB=postgres` - Database name
- `POSTGRES_USER=postgres` - Database username
- `POSTGRES_PASSWORD=postgres` - Database password
- `APP_URL=http://localhost:3000` - External URL for the service

## Usage Examples

**Build specific version locally:**
```bash
POCKET_ID_VERSION=1.8.0 docker compose up -d --build
```

**Use registry images:**
```bash
export POCKET_ID_IMAGE=ghcr.io/cougz/awesome-distroless/pocket-id:1.9.1
export POSTGRES_IMAGE=ghcr.io/cougz/awesome-distroless/postgres:17.5
docker compose up -d
```

**Force rebuild:**
```bash
docker compose build --no-cache
docker compose up -d
```

## Default Credentials

Default access: `http://localhost:3000`

Refer to [Pocket-ID documentation](https://github.com/pocket-id/pocket-id) for initial setup and configuration.

## Volumes

- `postgres_data` - PostgreSQL database storage
- `app_data` - Pocket-ID application data

## Security Features

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- No shell or package manager access
- Dropped Linux capabilities
- Temporary filesystem for /tmp
- Security profiles enabled

## Health Checks

- **Database**: PostgreSQL connection test
- **Application**: Pocket-ID version check

## Architecture

```
┌─────────────────┐    ┌──────────────────┐
│   Pocket-ID     │───▶│   PostgreSQL     │
│   (port 3000)   │    │   (port 5432)    │
│   distroless    │    │   distroless     │
└─────────────────┘    └──────────────────┘
```

## Troubleshooting

**Container fails to start:**
```bash
# Check logs
docker compose logs pocket-id-app
docker compose logs pocket-id-database

# Verify database is ready
docker compose exec pocket-id-database pg_isready -U postgres
```

**Permission issues:**
- Ensure `APP_UID` and `APP_GID` match your host user if mounting host directories
- Check volume permissions: `docker volume inspect pocket-id_app_data`

## License

[MIT](../LICENSE) - Same as parent project