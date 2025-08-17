# Distroless Redis

Minimal Redis container with no shell access.

## Quick Start

```bash
docker compose up -d
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PORT` | `6379` | Host port |

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `7.4.2` | Redis version |
| `APP_UID` | `1000` | User ID |
| `APP_GID` | `1000` | Group ID |

## Data Persistence

Data is stored in `./data` directory (auto-created by Docker).

## Security

Dangerous commands (FLUSHALL, CONFIG, etc.) are disabled.

## Health Check

Uses `redis-cli ping` for health monitoring.