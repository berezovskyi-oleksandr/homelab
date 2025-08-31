# Paperless-ngx Stack

A document management system that transforms your physical documents into a searchable online archive. Scan, index, and archive all your documents with powerful OCR and AI-powered organization.

## Services Overview

- **webserver**: Main Paperless-ngx application with web interface and API
- **db**: PostgreSQL database for document metadata and full-text search
- **broker**: Redis message broker for background task processing
- **gotenberg**: Document conversion service for Office files and web pages
- **tika**: Text extraction service for various file formats
- **backup-files**: Automated file backups using resticprofile with AWS S3
- **backup-database**: Automated PostgreSQL database dumps

## Key Features

- **OCR Processing**: Automatic text extraction from scanned documents
- **AI Tagging**: Machine learning-powered document classification and tagging
- **Full-Text Search**: Fast searching across all document contents
- **Document Types**: Support for PDF, images, Office documents, emails
- **Web Interface**: Modern, responsive web UI for document management
- **REST API**: Full API for integration with other applications
- **Barcode Support**: QR code and barcode recognition for automated filing
- **Email Integration**: Import documents via email
- **Multi-user**: User management with permission controls

## Links & Documentation

- **Official Website**: https://paperless-ngx.com/
- **GitHub Repository**: https://github.com/paperless-ngx/paperless-ngx
- **Documentation**: https://docs.paperless-ngx.com/
- **Docker Hub**: https://hub.docker.com/r/paperlessngx/paperless-ngx
- **Demo**: https://demo.paperless-ngx.com/ (admin/demo)
- **Community**: https://github.com/paperless-ngx/paperless-ngx/discussions

## Configuration

### Environment Variables
Copy `stack.env` to `stack.env.real` and configure:

- `PAPERLESS_*`: Application-specific settings (database, OCR languages, secret key)
- `TZ`: Timezone
- `TRAEFIK_DOMAIN`: Domain for web access
- `CONSUME_PATH`: Directory for automatic document consumption
- `AWS_*`: AWS S3 credentials for backups
- `SERVICE_DATA_ROOT_PATH`: Base path for service data
- `USERMAP_UID/USERMAP_GID`: User/group IDs for file permissions

### OCR Languages
Configure `PAPERLESS_OCR_LANGUAGE` and `PAPERLESS_OCR_LANGUAGES` for multi-language OCR support.

### Network Access
- **Web Interface**: Accessible via Traefik at configured domain
- **Document Consumption**: Place documents in the consume directory for automatic processing

## Document Processing Pipeline

1. **Intake**: Documents added via web upload, email, or consume folder
2. **OCR**: Text extraction using Tesseract with configured languages
3. **Text Extraction**: Additional text processing via Tika for office documents
4. **PDF Generation**: Gotenberg converts office documents to searchable PDFs
5. **Classification**: AI-powered tagging and document type detection
6. **Storage**: Organized storage with full-text search indexing

## Backup Strategy

**Database**: Hourly PostgreSQL dumps with 2-hour retention

**Files**: Automated S3 backups of documents and media using resticprofile

## Dependencies

- External Traefik reverse proxy network
- AWS S3 bucket for backups
- Consume directory for document intake
