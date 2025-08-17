# Distroless Nginx

Minimal Nginx container running rootless on port 8080.

## Quick Start

```bash
docker compose up -d
```

Access at: http://localhost:8080

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_PORT` | `8080` | Host port |

## Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.27.3` | Nginx version |
| `APP_UID` | `1000` | User ID |
| `APP_GID` | `1000` | Group ID |

## Content & Config

- Static content: `./html` directory (auto-created)
- Custom configs: `./config` directory (auto-created)

## Health Check

Uses `nginx -t` for configuration validation.