# Distroless PostgreSQL

Minimal PostgreSQL container with no shell access.

## Quick Start

```bash
docker compose up -d
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | `postgres` | Database password |
| `POSTGRES_DB` | `postgres` | Default database |
| `POSTGRES_PORT` | `5432` | Host port |

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `17.5` | PostgreSQL version |
| `APP_UID` | `1000` | User ID |
| `APP_GID` | `1000` | Group ID |

## Data Persistence

Data is stored in `./data` directory (auto-created by Docker).

## Health Check

Uses `pg_isready` for health monitoring.