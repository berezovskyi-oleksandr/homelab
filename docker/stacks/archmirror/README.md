# Arch Linux Mirror Stack

A self-hosted Arch Linux package mirror that provides local access to Arch Linux packages, reducing bandwidth usage and improving package download speeds for local Arch Linux systems.

## Services Overview

- **rsync-mirror**: Automated synchronization service that mirrors Arch Linux packages from upstream
- **nginx-server**: HTTP server that serves the mirrored packages to local clients

## Key Features

- **Automated Syncing**: Scheduled rsync synchronization with upstream Arch Linux mirrors
- **Local Package Serving**: Fast HTTP access to packages for local Arch Linux installations
- **Bandwidth Optimization**: Reduces external bandwidth usage for multiple Arch Linux systems
- **Health Monitoring**: Built-in health checks for both sync and web services
- **Customizable Sync**: Configurable sync schedules and rsync options

## Architecture

### Sync Process
1. **rsync-mirror** container runs scheduled sync jobs using supercronic
2. Downloads packages from configured upstream mirror
3. Stores packages in shared volume
4. **nginx-server** serves packages via HTTP

### Storage
- Shared volume between containers for package storage
- Read-only access for nginx service ensures data integrity
- Configurable storage path for flexible deployment

## Links & Documentation

### Arch Linux
- **Website**: https://archlinux.org/
- **Package Database**: https://archlinux.org/packages/
- **Mirror Status**: https://archlinux.org/mirrors/status/
- **Mirror Setup Guide**: https://wiki.archlinux.org/title/DeveloperWiki:NewMirrors

### Container Technologies
- **Docker Compose**: https://docs.docker.com/compose/
- **Nginx**: https://nginx.org/en/docs/
- **Supercronic**: https://github.com/aptible/supercronic

## Configuration

### Environment Variables
Copy `stack.env` to `stack.env.real` and configure:

- `MIRROR_URL`: Upstream Arch Linux mirror URL for rsync
- `SYNC_SCHEDULE`: Cron schedule for sync operations (e.g., "0 */4 * * *" for every 4 hours)
- `TZ`: Timezone for scheduling
- `RSYNC_EXTRA_OPTIONS`: Additional rsync options for fine-tuning
- `ARCHLINUX_VOLUME_PATH`: Local path for package storage
- `HTTP_PORT`: HTTP port for package access (default: 8080)
- `NGINX_WORKERS`: Number of nginx worker processes

### Network Access
- **HTTP Server**: Accessible on configured port (default: 8080)
- **Health Checks**: Both services include health monitoring

## Usage

### Client Configuration
Configure Arch Linux clients to use the local mirror by editing `/etc/pacman.d/mirrorlist`:

```
## Local mirror
Server = http://your-server-ip:8080/archlinux/$repo/os/$arch

## Fallback mirrors
# ... other mirrors
```

### Sync Monitoring
- Monitor sync container logs for sync status and errors
- Health checks ensure services are running properly
- Nginx access logs show package download activity

## Storage Requirements

- **Full Mirror**: ~60-80GB for complete Arch Linux repository
- **Growth**: Expect ~1-2GB growth per month
- **I/O**: SSD storage recommended for better performance during sync operations

## Sync Strategy

### Recommended Schedule
- **Frequent Updates**: Every 4-6 hours for active development
- **Conservative**: Daily syncs for stable environments
- **Bandwidth Considerations**: Schedule during low-usage periods

### Upstream Mirror Selection
Choose geographically close, reliable mirrors from the [official mirror list](https://archlinux.org/mirrorlist/).

## Custom Builds

The stack uses custom Dockerfiles for both rsync and nginx services, allowing for:
- Optimized container sizing
- Specific configuration needs
- Custom sync scripts and monitoring

## Dependencies

- Docker and Docker Compose
- Sufficient storage for package mirror
- Network access to upstream Arch Linux mirrors
