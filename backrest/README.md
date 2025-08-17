# Backrest Distroless

Minimal, secure [Backrest](https://github.com/garethgeorge/backrest) backup solution in a distroless container.

## What is Backrest?

Backrest is a web-based UI for restic backup tool, providing easy backup management with a modern interface.

## Features

- **Distroless security**: No shell, package manager, or unnecessary utilities
- **Multi-architecture**: Supports linux/amd64 and linux/arm64
- **Security hardened**: Read-only filesystem, non-root user, dropped capabilities
- **Built from source**: Compiled from official Backrest repository
- **Includes Restic**: Pre-installed restic backup engine v0.18.0
- **Built with Debian 13 (trixie)** for latest security patches

## Quick Start

### Option 1: Use Pre-built Images (Recommended)
```bash
# Copy environment file
cp .env.example .env

# Edit configuration as needed
nano .env

# Start with pre-built images
docker compose --profile image up -d
```

### Option 2: Build from Source
```bash
# Copy environment file  
cp .env.example .env

# Edit configuration as needed
nano .env

# Build and start
docker compose up -d
```

## Configuration

### Environment Variables

**Build Configuration:**
- `APP_UID=1000` - User ID for container user
- `APP_GID=1000` - Group ID for container user  
- `TZ=UTC` - Timezone setting
- `BACKREST_VERSION=1.9.1` - Backrest version to build

**Runtime Configuration:**
- `WEB_PORT=9898` - Port to expose on host
- `BACKREST_PORT=0.0.0.0:9898` - Internal bind address
- `BACKUP_SOURCE_PATH=./data` - Local path to backup (mounted as /userdata)

### First Run Setup

1. Access the web interface: `http://localhost:9898`
2. Configure your first repository through the UI
3. Set up backup plans for your data
4. Schedule backups as needed

## Volumes

- `data` - Backrest application data and database
- `config` - Backrest configuration files
- `cache` - Restic cache for improved performance
- `repos` - Backup repositories storage
- `./data:/userdata:ro` - Source data to backup (read-only)

## Security Features

- Runs as non-root user (UID 1000)
- Read-only root filesystem
- No shell or package manager access
- Dropped Linux capabilities
- Large temporary filesystem for backup operations (2GB default)
- Security profiles enabled

## Backup Workflow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Source Data   │───▶│    Backrest      │───▶│   Repositories  │
│   (/userdata)   │    │   (port 9898)    │    │    (/repos)     │
│   read-only     │    │   distroless     │    │   encrypted     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Health Checks

- **Application**: Backrest version check

## Usage Examples

### Basic Backup Setup
```bash
# Create data directory to backup
mkdir -p ./data
echo "Important files here" > ./data/important.txt

# Start Backrest
docker compose --profile image up -d

# Access web UI
open http://localhost:9898
```

### Custom Source Path
```bash
# Backup a different directory
BACKUP_SOURCE_PATH=/home/user/documents docker compose --profile image up -d
```

## Troubleshooting

**Container fails to start:**
```bash
# Check logs
docker compose logs backrest-app

# Verify permissions
ls -la ./data
```

**Backup fails:**
- Check source data permissions
- Ensure sufficient disk space in repos volume
- Verify TMPFS_SIZE is adequate for your backup size

**Web UI not accessible:**
- Verify port 9898 is not in use: `netstat -tlnp | grep 9898`
- Check firewall settings

## Restic Integration

Backrest includes restic v0.18.0 for backup operations. You can:
- Create multiple repositories
- Configure backup schedules
- Monitor backup progress
- Restore files through the web interface

## Performance Tuning

For large backups, consider:
- Increasing `TMPFS_SIZE` (default: 2G)
- Using dedicated volumes for repositories
- Adjusting cache volume size

## License

[MIT](../LICENSE) - Same as parent project