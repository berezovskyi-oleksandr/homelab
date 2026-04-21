# Homelab Infrastructure

Self-hosted services running on a single-node Talos Kubernetes cluster, provisioned via Terraform on Proxmox and managed through Flux CD GitOps.

## Architecture

```
Proxmox (hypervisor)
└── Talos Linux VM (Kubernetes node)
    └── Flux CD (GitOps)
        ├── config          → cluster-wide variables & secrets
        ├── infrastructure  → Traefik, cert-manager, Authelia, MetalLB, NFS, ...
        └── apps            → application workloads
```

### Repository Layout

```
homelab-v2/
├── terraform/      # Proxmox VM + Talos cluster provisioning
└── kubernetes/     # Flux CD manifests (Kustomize + Helm)
    ├── config/
    ├── flux-system/
    ├── infrastructure/
    │   ├── controllers/    # Traefik, cert-manager, Authelia, MetalLB, ...
    │   └── configs/        # ClusterIssuer, MetalLB config
    ├── app/
    │   ├── archmirror/
    │   ├── external/       # External service vars (e.g. Home Assistant)
    │   ├── firefly/
    │   ├── grocy/
    │   ├── homepage/
    │   ├── immich/
    │   ├── jellyfin/
    │   ├── lubelogger/
    │   ├── media/
    │   ├── paperless/
    │   ├── pihole/
    │   └── podsync/
    └── docs/
        └── k8s-service-spec.md
```

## Services

| Service | Description |
|---------|-------------|
| **Firefly III** | Personal finance manager |
| **Immich** | Photo and video management with face recognition |
| **Jellyfin** | Media streaming with Intel GPU hardware transcoding |
| **Media Stack** | Sonarr, Radarr, Prowlarr, qBittorrent — automated media acquisition |
| **Paperless-ngx** | Document management with OCR |
| **Pi-hole** | DNS sinkhole with ad blocking and encrypted DNS via dnscrypt-proxy |
| **Grocy** | Pantry and grocery management |
| **LubeLogger** | Vehicle maintenance tracker |
| **Homepage** | Dashboard aggregator |
| **Podsync** | Podcast downloader |
| **Archmirror** | Local Arch Linux package repository mirror |

## Infrastructure Stack

| Component | Role |
|-----------|------|
| **Flux CD** | GitOps controller — reconciles this repo to the cluster |
| **Traefik** | Ingress controller with Let's Encrypt TLS |
| **cert-manager** | TLS certificate provisioning (Cloudflare DNS-01) |
| **Authelia** | SSO / OIDC provider for protected services |
| **MetalLB** | Bare-metal load balancer |
| **NFS Provisioner** | Dynamic PVC provisioning backed by Synology NAS |
| **Intel GPU Plugin** | Hardware transcoding device plugin (Jellyfin) |
| **SOPS + age** | Secret encryption at rest |

### Storage

- **Synology NAS** — primary storage backend for all services
  - Dynamic NFS PVCs via `nfs-synology-ssd` storage class
  - Static NFS PVs for media library and document archives
- **local-path-provisioner** — node-local storage for SQLite databases

### Backups

Unified strategy using **restic + resticprofile**:

- **Primary**: Synology NAS via `rest-server` container (`${BACKUP_LOCAL_HOST}:8000`)
- **Secondary**: Backblaze B2 (offsite), synced via `resticprofile copy`
- PostgreSQL: pg_dump init container → restic
- SQLite: online backup API → restic
- Files/media: NFS mount → restic

## Deployment

All changes are deployed by pushing to this repository. Flux CD reconciles on every commit.

```sh
# Check reconciliation status
flux get kustomizations

# Force reconciliation
flux reconcile source git flux-system

# Check application status
kubectl get helmreleases -A
kubectl get pods -A
```

For initial cluster bootstrap, see [`kubernetes/README.md`](kubernetes/README.md).

## Security

- All ingress through Traefik with Let's Encrypt TLS
- Secrets encrypted with SOPS + age (decrypted at runtime by Flux)
- SSO via Authelia (OIDC) for user-facing services
- Per-namespace NetworkPolicies with default-deny + explicit Traefik ingress allow

## Provisioning

The cluster is provisioned with Terraform (Proxmox + Talos). See [`terraform/README.md`](terraform/README.md).
