# Distroless Nginx

Minimal, secure Nginx container running on distroless base with rootless operation on port 8080.

## Quick Start

```bash
git clone <repository>
cd nginx
docker-compose up -d
```

Access nginx at: http://localhost:8080

## Features

- **Distroless**: No shell, no package manager, minimal attack surface
- **Rootless**: Runs as UID 1000 on port 8080 (non-privileged)
- **Configurable**: UID/GID, timezone, and versions via build args
- **Bind Mounts**: HTML content and configuration via bind mounts
- **Secure**: Read-only root filesystem, dropped capabilities
- **Health Checks**: Built-in nginx configuration validation

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_PORT` | `8080` | Host port mapping |
| `TZ` | `UTC` | Container timezone |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `1.27.3` | Nginx version |
| `APP_UID` | `1000` | User ID for app user |
| `APP_GID` | `1000` | Group ID for app user |
| `TZ` | `UTC` | Build-time timezone |

### Bind Mounts

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `./html` | `/usr/share/nginx/html` | Website content (read-only) |
| `./config` | `/etc/nginx/conf.d` | Additional server configurations (read-only) |

## Usage Examples

### Basic Usage

```bash
# Start nginx
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs nginx
```

### Custom Content

```bash
# Add your website files to ./html/
echo "<h1>Hello World!</h1>" > html/index.html

# Restart to reload content
docker-compose restart nginx
```

### Custom Configuration

Create additional server blocks in `./config/`:

```bash
# Create a new server configuration
cat > config/api.conf << 'EOF'
server {
    listen 8080;
    server_name api.localhost;
    
    location /api {
        proxy_pass http://backend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Reload configuration
docker-compose restart nginx
```

### Different Port

```bash
# Run on port 9080
NGINX_PORT=9080 docker-compose up -d
```

### Custom Build

```bash
# Build with different UID/GID
docker-compose build --build-arg APP_UID=2000 --build-arg APP_GID=2000

# Build different Nginx version
docker-compose build --build-arg VERSION=1.26.2
```

## Health Check

The container includes nginx configuration validation:

```bash
# Check health status
docker-compose ps

# Manual health check
docker exec distroless-nginx /usr/local/bin/nginx -t

# View health check logs
docker inspect --format='{{json .State.Health}}' distroless-nginx
```

## Content Management

### Static Website

```bash
# Copy static site to html directory
cp -r /path/to/your/website/* html/

# Nginx will serve files immediately (read-only bind mount)
```

### Single Page Application (SPA)

```bash
# For React/Vue/Angular apps, add try_files directive
cat > config/spa.conf << 'EOF'
server {
    listen 8080;
    server_name spa.localhost;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
```

## Security Features

- **Distroless base**: No shell access, minimal packages
- **Non-root user**: Runs as UID 1000 on port 8080
- **Read-only root**: Filesystem is read-only except tmpfs
- **Dropped capabilities**: ALL capabilities dropped
- **No new privileges**: Prevents privilege escalation
- **Minimal libraries**: Only essential libraries included

## Performance Tuning

### Resource Limits

```yaml
# In docker-compose.yml, adjust resources:
deploy:
  resources:
    limits:
      memory: 128M
      cpus: '0.5'
    reservations:
      memory: 32M
```

### Worker Configuration

```bash
# Modify nginx.conf for more workers
cat > config/performance.conf << 'EOF'
worker_processes 4;
worker_connections 2048;

# Enable additional performance features
sendfile on;
tcp_nopush on;
tcp_nodelay on;
keepalive_timeout 30;
EOF
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs nginx

# Common issues:
# 1. Port already in use
NGINX_PORT=9080 docker-compose up -d

# 2. Configuration syntax error
docker exec distroless-nginx /usr/local/bin/nginx -t
```

### Permission Issues

```bash
# Ensure proper ownership of mounted content
sudo chown -R 1000:1000 html/ config/

# Check file permissions
ls -la html/ config/
```

### Configuration Not Loading

```bash
# Verify config file syntax
docker exec distroless-nginx /usr/local/bin/nginx -t

# Reload configuration
docker-compose restart nginx
```

### Performance Issues

```bash
# Monitor resource usage
docker stats distroless-nginx

# Check nginx status
curl http://localhost:8080/health
```

## Image Size

- Base image: ~850KB
- Nginx image: ~12MB
- Includes: Nginx binary, SSL support, essential modules

## Security Considerations

1. **Content Security**: Only serve trusted content via bind mounts
2. **Configuration**: Review all configuration files for security
3. **Updates**: Rebuild regularly for security updates
4. **Monitoring**: Monitor access logs for suspicious activity
5. **Network**: Use Docker networks for service communication

## Common Patterns

### Reverse Proxy

```bash
cat > config/proxy.conf << 'EOF'
upstream backend {
    server app:3000;
}

server {
    listen 8080;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

### Static + API

```bash
cat > config/mixed.conf << 'EOF'
server {
    listen 8080;
    
    # Static content
    location / {
        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;
    }
    
    # API proxy
    location /api/ {
        proxy_pass http://api-server:8000/;
    }
}
EOF
```