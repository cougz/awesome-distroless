# Distroless Redis

Minimal Redis container with no shell access.

## Quick Start

```bash
docker compose up -d
```

## Configuration

Copy `.env.example` to `.env` and customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PORT` | `6379` | Host port |
| `TZ` | `UTC` | Container timezone |

## Data Persistence

Data is stored in `./data` directory (auto-created by Docker).

## Security

- Built with Debian 13 (trixie) for latest security patches
- Runs as UID 1000 (non-root)
- No shell access (distroless)
- Dangerous commands (FLUSHALL, CONFIG, etc.) disabled
- Health monitoring with `redis-cli ping`