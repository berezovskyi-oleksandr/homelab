# Docker Stacks

Individual service stacks with comprehensive documentation. See the [main README](../../README.md) for architecture overview and deployment process.

## Available Stacks

| Stack | Description | Port(s) | Mobile/Remote Access |
|-------|-------------|---------|---------------------|
| [**Immich**](./immich/) | Photo and video management with AI | 2283 | iOS/Android apps |
| [**Paperless-ngx**](./paperless/) | Document management with OCR | Web UI | Email integration |
| [**Media**](./media/) | *arr suite for media automation | 8989, 7878, 9696, 8114 | nzb360 mobile app |
| [**Pi-hole**](./pihole/) | Network-wide ad blocker | 53, 80 | Web dashboard |
| [**Arch Mirror**](./archmirror/) | Local Arch Linux package mirror | 8080 | pacman client |

## Quick Start

1. Choose a stack from the table above
2. Read the stack's README for setup instructions  
3. Copy environment template: `cp stack.env stack.env.real`
4. Configure variables in `stack.env.real`
5. Deploy via Portainer using the docker-compose.yaml

Each stack directory contains:
- `docker-compose.yaml` - Service definitions
- `stack.env` - Environment template (tracked in git)  
- `stack.env.real` - Actual values with secrets (gitignored)
- `README.md` - Detailed documentation
