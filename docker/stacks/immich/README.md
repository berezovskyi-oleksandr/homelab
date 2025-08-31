# Immich Stack

A high-performance photo and video management solution that makes organizing and sharing your media collection effortless.

## Services Overview

- **immich-server**: Main application server providing web interface and API
- **immich-machine-learning**: AI-powered features for face recognition, object detection, and smart search
- **redis**: In-memory data store for caching and session management
- **database**: PostgreSQL database with vector extensions for ML features
- **backup-files**: Automated file backups using resticprofile with AWS S3
- **backup-database**: Automated PostgreSQL database dumps

## Key Features

- **Smart Photo Management**: AI-powered face recognition, object detection, and duplicate detection
- **Mobile Apps**: Native iOS and Android apps with automatic photo backup
- **Video Support**: Hardware-accelerated video transcoding and streaming
- **Sharing**: Secure photo and album sharing with customizable permissions
- **Search**: Powerful search capabilities using AI and metadata
- **Multi-user**: Support for multiple users with individual libraries
- **Backup**: Automated backups to AWS S3 for both files and database

## Links & Documentation

- **Official Website**: https://immich.app/
- **GitHub Repository**: https://github.com/immich-app/immich
- **Documentation**: https://immich.app/docs/overview/introduction
- **Docker Hub**: https://hub.docker.com/r/immich-app/immich-server
- **Mobile Apps**:
  - [iOS App Store](https://apps.apple.com/us/app/immich/id1613945652)
  - [Android Play Store](https://play.google.com/store/apps/details?id=app.alextran.immich)

## Configuration

### Environment Variables
Copy `stack.env` to `stack.env.real` and configure:

- `IMMICH_VERSION`: Docker image version (default: release)
- `UPLOAD_LOCATION`: Path for photo/video storage
- `DB_*`: PostgreSQL database credentials
- `TZ`: Timezone
- `TRAEFIK_DOMAIN`: Domain for web access
- `AWS_*`: AWS S3 credentials for backups
- `SERVICE_DATA_ROOT_PATH`: Base path for service data

### Network Access
- **Web Interface**: Accessible via Traefik at configured domain
- **Port**: 2283 (internal Docker port 3001)
- **Mobile Apps**: Connect using the configured domain

## Backup Strategy

**Database**: Hourly PostgreSQL dumps with 2-hour retention

**Files**: Automated S3 backups of uploaded photos/videos using resticprofile

## Dependencies

- External Traefik reverse proxy network
- AWS S3 bucket for backups
