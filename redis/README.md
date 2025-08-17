# Distroless Redis

Minimal, secure Redis container running on distroless base with no shell access.

## Quick Start

```bash
git clone <repository>
cd redis
docker-compose up -d
```

## Features

- **Distroless**: No shell, no package manager, minimal attack surface
- **Rootless**: Runs as UID 1000 (app user)
- **Configurable**: UID/GID, timezone, and versions via build args
- **Persistent**: Data stored in bind mount (./data)
- **Secure**: Read-only root filesystem, dropped capabilities, disabled dangerous commands
- **Health Checks**: Built-in Redis health monitoring with ping

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_PORT` | `6379` | Host port mapping |
| `TZ` | `UTC` | Container timezone |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `VERSION` | `7.4.2` | Redis version |
| `APP_UID` | `1000` | User ID for app user |
| `APP_GID` | `1000` | Group ID for app user |
| `TZ` | `UTC` | Build-time timezone |

### Bind Mounts

| Host Path | Container Path | Description |
|-----------|----------------|-------------|
| `./data` | `/data` | Redis data directory |
| `./redis.conf` | `/etc/redis/redis.conf` | Redis configuration file (read-only) |

## Usage Examples

### Basic Usage

```bash
# Start Redis
docker-compose up -d

# Connect with redis-cli (requires Redis client)
redis-cli -h localhost -p 6379

# Check status
docker-compose ps
```

### Custom Configuration

Edit `redis.conf` to customize Redis behavior:

```bash
# Edit configuration
nano redis.conf

# Common settings to modify:
# maxmemory 256mb
# maxmemory-policy allkeys-lru
# save 900 1

# Restart to apply changes
docker-compose restart redis
```

### Custom Port

```bash
# Run on port 6380
REDIS_PORT=6380 docker-compose up -d
```

### Build with Custom Options

```bash
# Build with different UID/GID
docker-compose build --build-arg APP_UID=2000 --build-arg APP_GID=2000

# Build different Redis version
docker-compose build --build-arg VERSION=7.2.6
```

## Health Check

The container includes a built-in health check using Redis ping:

```bash
# Check health status
docker-compose ps

# Manual health check
docker exec distroless-redis /usr/local/bin/redis-cli ping

# View health check logs
docker inspect --format='{{json .State.Health}}' distroless-redis
```

## Data Persistence

Data is persisted in the `./data` directory via bind mount:

```bash
# Backup data
tar -czf redis-backup.tar.gz data/

# Restore data (container must be stopped)
docker-compose down
tar -xzf redis-backup.tar.gz
docker-compose up -d
```

## Security Features

- **Distroless base**: No shell access, minimal packages
- **Non-root user**: Runs as UID 1000
- **Read-only root**: Filesystem is read-only except tmpfs
- **Dropped capabilities**: ALL capabilities dropped
- **No new privileges**: Prevents privilege escalation
- **Disabled commands**: Dangerous commands like FLUSHALL, CONFIG disabled
- **Network security**: Protected mode disabled for container networking

## Performance Tuning

### Memory Configuration

```bash
# Edit redis.conf for memory limits
cat >> redis.conf << 'EOF'
maxmemory 512mb
maxmemory-policy allkeys-lru
EOF
```

### Persistence Settings

```bash
# Adjust save frequency in redis.conf
# More frequent saves (more writes, safer):
save 300 10
save 60 1000

# Less frequent saves (better performance):
save 900 1
save 300 100
```

### Resource Limits

```yaml
# In docker-compose.yml, adjust resources:
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
    reservations:
      memory: 128M
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs redis

# Common issues:
# 1. Port already in use
REDIS_PORT=6380 docker-compose up -d

# 2. Configuration syntax error
# Check redis.conf syntax

# 3. Data directory permissions
sudo chown -R 1000:1000 data/
```

### Connection Issues

```bash
# Verify container is healthy
docker-compose ps

# Check if port is accessible
telnet localhost 6379

# Test with redis-cli
docker exec distroless-redis /usr/local/bin/redis-cli ping
```

### Performance Issues

```bash
# Monitor Redis performance
docker exec distroless-redis /usr/local/bin/redis-cli info

# Check memory usage
docker exec distroless-redis /usr/local/bin/redis-cli info memory

# Monitor resource usage
docker stats distroless-redis
```

### Data Corruption

```bash
# Check RDB file integrity
docker exec distroless-redis /usr/local/bin/redis-cli LASTSAVE

# Force background save
docker exec distroless-redis /usr/local/bin/redis-cli BGSAVE
```

## Configuration Reference

### Key Settings in redis.conf

```bash
# Network
bind 0.0.0.0              # Listen on all interfaces
port 6379                 # Redis port
protected-mode no         # Disable for container networking

# Persistence
save 900 1                # Save after 900 sec if at least 1 key changed
save 300 10               # Save after 300 sec if at least 10 keys changed
save 60 10000            # Save after 60 sec if at least 10000 keys changed
dir /data                 # Data directory
dbfilename dump.rdb       # RDB filename

# Memory
maxmemory-policy allkeys-lru  # Eviction policy

# Security
rename-command FLUSHDB ""     # Disable dangerous commands
rename-command FLUSHALL ""
rename-command KEYS ""
rename-command DEBUG ""
rename-command CONFIG ""
```

## Image Size

- Base image: ~850KB
- Redis image: ~8MB
- Includes: Redis server, Redis CLI, minimal libraries

## Security Considerations

1. **Network**: Use Docker networks for service-to-service communication
2. **Authentication**: Consider enabling AUTH for production
3. **Commands**: Review disabled commands based on your needs
4. **Updates**: Rebuild regularly for security updates
5. **Monitoring**: Monitor Redis logs for suspicious activity
6. **Backups**: Regular automated backups are essential

## Common Use Cases

### Session Store

```python
# Python example using redis-py
import redis

r = redis.Redis(host='localhost', port=6379, decode_responses=True)
r.setex('session:user123', 3600, 'session_data')
```

### Cache

```javascript
// Node.js example
const redis = require('redis');
const client = redis.createClient({
  host: 'localhost',
  port: 6379
});

await client.setEx('cache:key', 300, 'cached_value');
```

### Message Queue

```bash
# Using Redis lists as queues
docker exec distroless-redis /usr/local/bin/redis-cli LPUSH task_queue "job1"
docker exec distroless-redis /usr/local/bin/redis-cli RPOP task_queue
```