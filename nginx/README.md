# Distroless Nginx

Minimal Nginx container running rootless on port 8080.

## Quick Start

```bash
docker compose up -d
```

Access at: http://localhost:8080

## Configuration

Copy `.env.example` to `.env` and customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_PORT` | `8080` | Host port |
| `TZ` | `UTC` | Container timezone |

## Content & Config

- Static content: `./html` directory (auto-created)
- Custom configs: `./config` directory (auto-created)

## Security

- Built with Debian 13 (trixie) for latest security patches
- Runs as UID 1000 on port 8080 (rootless)
- No shell access (distroless)
- Health monitoring with `nginx -t`