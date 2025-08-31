# Media Stack (*arr Suite)

A complete media automation solution that automatically downloads, organizes, and manages your TV shows and movies. This stack combines the popular *arr applications with a torrent client for a fully automated media center.

## Services Overview

- **sonarr**: TV series management and automation with PostgreSQL backend
- **radarr**: Movie management and automation with PostgreSQL backend  
- **prowlarr**: Indexer manager for torrent and usenet sources
- **qbittorrent**: BitTorrent client for downloading media
- **sonarr-db**: Dedicated PostgreSQL database for Sonarr
- **radarr-db**: Dedicated PostgreSQL database for Radarr

## Key Features

- **Automated Downloads**: Monitor RSS feeds and automatically download new episodes/movies
- **Quality Management**: Configurable quality profiles and upgrade automation
- **Release Profiles**: Advanced filtering and scoring of releases
- **Calendar Integration**: Track upcoming releases and air dates
- **Metadata Management**: Automatic metadata and artwork fetching
- **Notifications**: Webhooks and notifications for downloads and imports
- **API Integration**: Full REST APIs for external integrations
- **Multi-Profile**: Support for different quality and language profiles

## Application Details

### Sonarr
- **TV Series Management**: Monitors TV show RSS feeds and manages series libraries
- **Season Management**: Handles season packs and individual episodes
- **Episode Renaming**: Automatic file renaming with customizable patterns

### Radarr  
- **Movie Management**: Monitors movie releases and manages movie libraries
- **Collection Support**: Handle movie collections and franchises
- **Release Monitoring**: Track theatrical, digital, and physical releases

### Prowlarr
- **Indexer Management**: Central management for all torrent/usenet indexers
- **Sync to Apps**: Automatically syncs indexers to Sonarr and Radarr
- **Statistics**: Download and indexer performance statistics

### qBittorrent
- **Torrent Client**: Handles all BitTorrent downloads for the media stack
- **Category Support**: Automatic categorization for different media types
- **API Access**: HTTP-protected API for *arr application integration

## Links & Documentation

### Sonarr
- **Website**: https://sonarr.tv/
- **GitHub**: https://github.com/Sonarr/Sonarr
- **Documentation**: https://wiki.servarr.com/sonarr
- **Docker**: https://hub.docker.com/r/linuxserver/sonarr

### Radarr
- **Website**: https://radarr.video/
- **GitHub**: https://github.com/Radarr/Radarr
- **Documentation**: https://wiki.servarr.com/radarr
- **Docker**: https://hub.docker.com/r/linuxserver/radarr

### Prowlarr
- **Website**: https://prowlarr.com/
- **GitHub**: https://github.com/Prowlarr/Prowlarr
- **Documentation**: https://wiki.servarr.com/prowlarr
- **Docker**: https://hub.docker.com/r/linuxserver/prowlarr

### qBittorrent
- **Website**: https://www.qbittorrent.org/
- **GitHub**: https://github.com/qbittorrent/qBittorrent
- **Documentation**: https://github.com/qbittorrent/qBittorrent/wiki
- **Docker**: https://hub.docker.com/r/linuxserver/qbittorrent

### nzb360
- **Mobile App**: Remote management client for *arr applications
- **Website**: https://nzb360.com/
- **Android**: https://play.google.com/store/apps/details?id=com.kevinforeman.nzb360
- **iOS**: https://apps.apple.com/app/nzb360/id1116293427

## Configuration

### Environment Variables
Copy `stack.env` to `stack.env.real` and configure:

- `PUID/PGID`: User and group IDs for file permissions
- `TZ`: Timezone
- `MEDIA_PATH`: Root path for media storage
- `SERVICE_DATA_ROOT_PATH`: Base path for application data
- `*_SERVICE_DOMAIN`: Traefik domains for each service
- `*_BASIC_AUTH`: HTTP basic authentication credentials
- `*_DB_*`: PostgreSQL database credentials for Sonarr/Radarr

### Network Access
- **Sonarr Web UI**: Port 8989
- **Radarr Web UI**: Port 7878
- **Prowlarr Web UI**: Port 9696
- **qBittorrent Web UI**: Port 8114 (also accessible via Traefik with authentication)

### API Access
API endpoints are exposed through Traefik with HTTP basic authentication for secure external access. These APIs are configured for integration with **nzb360**, a mobile app for managing *arr applications and download clients remotely.

## Media Organization

### Directory Structure
```
/media/
├── downloads/          # qBittorrent download directory
├── tv/                 # TV shows library (Sonarr)
├── movies/             # Movies library (Radarr)
└── ...                 # Additional media directories
```

### File Permissions
All services run with consistent PUID/PGID to ensure proper file access across the media path.

## Database Backend

Both Sonarr and Radarr use dedicated PostgreSQL databases for improved performance and reliability compared to SQLite.

## Dependencies

- External Traefik reverse proxy network for secure API access
- Shared media storage path accessible by all services
- Network connectivity between services for API communication
