# Distroless PostgreSQL

Minimal, secure PostgreSQL container running on distroless base with no shell access.

## Quick Start

```bash
git clone <repository>
cd postgres
docker-compose up -d
```

## Features

- **Distroless**: No shell, no package manager, minimal attack surface
- **Rootless**: Runs as UID 1000 (app user)
- **Configurable**: UID/GID, timezone, and versions via build args
- **Persistent**: Data stored in bind mount (./data)
- **Secure**: Read-only root filesystem, dropped capabilities
- **Health Checks**: Built-in PostgreSQL health monitoring

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | Database superuser name |
| `POSTGRES_PASSWORD` | `postgres` | Database superuser password |
| `POSTGRES_DB` | `postgres` | Default database name |
| `POSTGRES_PORT` | `5432` | Host port mapping |
| `TZ` | `UTC` | Container timezone |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `17.5` | PostgreSQL version |
| `APP_UID` | `1000` | User ID for app user |
| `APP_GID` | `1000` | Group ID for app user |
| `TZ` | `UTC` | Build-time timezone |

### Bind Mounts

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `./data` | `/var/lib/postgresql/data` | PostgreSQL data directory |

## Usage Examples

### Basic Usage

```bash
# Start PostgreSQL
docker-compose up -d

# Connect with psql (requires PostgreSQL client)
psql -h localhost -U postgres -d postgres

# Check status
docker-compose ps
```

### Custom Configuration

```bash
# Custom user/password
POSTGRES_USER=myuser POSTGRES_PASSWORD=mypass docker-compose up -d

# Custom port
POSTGRES_PORT=5433 docker-compose up -d

# Custom timezone
TZ=America/New_York docker-compose up -d
```

### Build with Custom Options

```bash
# Build with different UID/GID
docker-compose build --build-arg APP_UID=2000 --build-arg APP_GID=2000

# Build different PostgreSQL version
docker-compose build --build-arg VERSION=16.6
```

## Health Check

The container includes a built-in health check using `pg_isready`:

```bash
# Check health status
docker-compose ps

# View health check logs
docker inspect --format='{{json .State.Health}}' distroless-postgres
```

## Data Persistence

Data is persisted in the `./data` directory via bind mount:

```bash
# Backup data
tar -czf postgres-backup.tar.gz data/

# Restore data (container must be stopped)
docker-compose down
tar -xzf postgres-backup.tar.gz
docker-compose up -d
```

## Security Features

- **Distroless base**: No shell access, minimal packages
- **Non-root user**: Runs as UID 1000
- **Read-only root**: Filesystem is read-only except tmpfs
- **Dropped capabilities**: ALL capabilities dropped
- **No new privileges**: Prevents privilege escalation

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs postgres

# Common issues:
# 1. Data directory permissions
sudo chown -R 1000:1000 data/

# 2. Port already in use
POSTGRES_PORT=5433 docker-compose up -d
```

### Connection Issues

```bash
# Verify container is healthy
docker-compose ps

# Check if port is accessible
telnet localhost 5432

# Test with pg_isready
docker exec distroless-postgres /usr/local/bin/pg_isready -U postgres
```

### Performance Tuning

Edit `data/postgresql.conf` for custom settings:

```bash
# Stop container
docker-compose down

# Edit configuration
nano data/postgresql.conf

# Restart with new settings
docker-compose up -d
```

## Image Size

- Base image: ~850KB
- PostgreSQL image: ~45MB
- Includes: PostgreSQL binaries, SSL support, timezone data

## Security Considerations

1. **Network**: Use Docker networks for service-to-service communication
2. **Passwords**: Use strong passwords or external secrets
3. **Updates**: Rebuild regularly for security updates
4. **Monitoring**: Monitor logs for suspicious activity
5. **Backups**: Regular automated backups are essential