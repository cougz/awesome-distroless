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

### Option 1: Use Pre-built Images (Recommended)
```bash
# Copy environment file
cp .env.example .env

# Edit configuration as needed
nano .env

# Start with pre-built images
docker compose --profile image up -d
```

### Option 2: Build from Source
```bash
# Copy environment file  
cp .env.example .env

# Edit configuration as needed
nano .env

# Build and start
docker compose up -d
```

## Configuration

### Environment Variables

**Build Configuration:**
- `APP_UID=1000` - User ID for container user
- `APP_GID=1000` - Group ID for container user  
- `TZ=UTC` - Timezone setting
- `POCKET_ID_VERSION=1.7.0` - Pocket-ID version to build

**Runtime Configuration:**
- `WEB_PORT=3000` - Port to expose on host
- `POSTGRES_DB=postgres` - Database name
- `POSTGRES_USER=postgres` - Database username
- `POSTGRES_PASSWORD=postgres` - Database password
- `APP_URL=http://localhost:3000` - External URL for the service

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