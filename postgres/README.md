# Distroless PostgreSQL

Minimal PostgreSQL container with no shell access.

## Quick Start

```bash
docker compose up -d
```

## Configuration

Copy `.env.example` to `.env` and customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | `postgres` | Database password |
| `POSTGRES_DB` | `postgres` | Default database |
| `POSTGRES_PORT` | `5432` | Host port |
| `TZ` | `UTC` | Container timezone |

## Data Persistence

Data is stored in `./data` directory (auto-created by Docker).

## Security

- Built with Debian 13 (trixie) for latest security patches
- Runs as UID 1000 (non-root)
- No shell access (distroless)
- Health monitoring with `pg_isready`