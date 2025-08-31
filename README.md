# Homelab Infrastructure

A collection of self-hosted services running on Docker containers, orchestrated through Portainer and exposed via Traefik reverse proxy.

## Architecture

This homelab uses a stack-based approach where each service is containerized and deployed as a complete stack with its dependencies. All services integrate with a centralized Traefik instance for SSL termination and domain routing.

### Stack Structure
```
docker/stacks/<service>/
 - docker-compose.yaml   # Service definition
 - stack.env             # Environment template (tracked)
 - stack.env.real        # Actual values with secrets (gitignored)
```

## Services

| Service | Description | Purpose |
|---------|-------------|---------|
| **Immich** | Self-hosted photo and video management | Personal media library with ML features |
| **Paperless-ngx** | Document management system with OCR | Digital document archive and search |
| **Media Stack** | Sonarr, Radarr, Prowlarr, qBittorrent | Automated media acquisition and management |
| **Pi-hole** | DNS sinkhole with ad blocking and dnscrypt-proxy | Network-wide ad blocking and encrypted DNS |
| **Arch Mirror** | Local Arch Linux package repository mirror | Local package cache for faster updates |

## Deployment

Services are deployed through **Portainer WebUI**:

1. Access Portainer dashboard
2. Navigate to Stacks section
3. Create new stack or update existing
4. Copy content from `docker-compose.yaml`
5. Configure environment variables from `stack.env.real`
6. Deploy stack

### Environment Setup

For each stack:
```bash
cd docker/stacks/<service>/
cp stack.env stack.env.real
# Edit stack.env.real with actual values
```

## Common Operations

### Stack Management
- Stack status and logs monitored through Portainer WebUI dashboard
- Updates performed by pulling new images and recreating containers

### Backup Operations
Each stack includes automated backup services:
- **Database backups**: Hourly PostgreSQL dumps using postgres-backup-local
- **File backups**: Scheduled Restic backups to AWS S3 backend

## Network Architecture

- **traefik** (external): Reverse proxy network for SSL termination and routing
- **service-specific**: Internal networks for each stack (immich, paperless, sonarr, radarr)
- Services primarily accessed through Traefik with minimal direct port exposure

## Security

- All services behind Traefik reverse proxy with Let's Encrypt SSL certificates
- Environment variables with secrets stored in `*.env.real` files (gitignored)
- API endpoints protected with HTTP basic authentication where applicable
- Internal service communication isolated over Docker networks

## Requirements

- Docker and Docker Compose
- Portainer CE for stack management
- Traefik reverse proxy (external dependency)
- Valid domain names for SSL certificate generation

## Notes

- This repository contains infrastructure definitions only
- Actual deployment and management handled through Portainer WebUI
