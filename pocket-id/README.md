# Pocket-ID Distroless

Minimal, secure [Pocket-ID](https://github.com/pocket-id/pocket-id) authentication service in a distroless container.

## What is Pocket-ID?

Pocket-ID is a lightweight, self-hosted OAuth2 and OpenID Connect provider that simplifies authentication for your applications.

## Features

- **Distroless security**: No shell, package manager, or unnecessary utilities
- **Security hardened**: Read-only filesystem, non-root user, dropped capabilities
- **Pre-built images**: Ready-to-use images from GitHub Container Registry
- **Built from source**: Compiled from official Pocket-ID repository
- **Integrated database**: Includes PostgreSQL for complete stack
- **Built with Debian 13 (trixie)** for latest security patches

## Quick Start

```bash
# Copy environment file
cp .env.example .env

# Edit configuration as needed
nano .env

# Start services (pulls images from ghcr.io)
docker compose up -d
```

The compose file automatically pulls pre-built images from GitHub Container Registry:
- `ghcr.io/cougz/awesome-distroless/pocket-id:1.10.0`
- `ghcr.io/cougz/awesome-distroless/postgres:17.6`

## Configuration

### Environment Variables

**Runtime Configuration:**
- `WEB_PORT=3000` - Port to expose on host
- `POSTGRES_DB=postgres` - Database name
- `POSTGRES_USER=postgres` - Database username
- `POSTGRES_PASSWORD=postgres` - Database password
- `APP_URL=http://localhost:3000` - External URL for the service
- `TZ=UTC` - Timezone setting
- `TMPFS_SIZE=1G` - Temporary filesystem size

## Building from Source

If you want to build your own images:

1. Fork this repository
2. Modify the `compose.yml` to add a build section pointing to your Dockerfile
3. Build with: `docker compose build`

The provided compose file uses pre-built images for simplicity and security.

## Default Access

Default URL: `http://localhost:3000`

Refer to [Pocket-ID documentation](https://github.com/pocket-id/pocket-id) for initial setup and configuration.

## Volumes

- `database` - PostgreSQL database storage
- `app` - Pocket-ID application data

## Security Features

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- No shell or package manager access
- Dropped Linux capabilities
- Temporary filesystem for /tmp
- Security profiles enabled

## Health Checks

- **Database**: PostgreSQL connection test
- **Application**: Pocket-ID health check

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
docker compose logs app
docker compose logs database

# Verify database is ready
docker compose exec database pg_isready -U postgres
```

**Permission issues:**
- The containers run with UID/GID 1000 by default
- Check volume permissions: `docker volume inspect pocket-id_app`

## License

[MIT](../LICENSE) - Same as parent project