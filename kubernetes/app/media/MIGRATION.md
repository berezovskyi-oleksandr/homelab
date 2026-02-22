# Media Stack Migration Guide

This document describes how to migrate the existing Docker Compose media stack (Sonarr, Radarr, Prowlarr, qBittorrent with PostgreSQL backends) to this Kubernetes deployment.

## Overview

The migration involves moving seven categories of data:

1. **PostgreSQL databases** (`sonarr-main`, `radarr-main`) -- series/movie metadata, history, quality profiles
2. **Sonarr configuration** (`config.xml`, MediaCover cache)
3. **Radarr configuration** (`config.xml`, MediaCover cache)
4. **Prowlarr configuration** (`config.xml`, `prowlarr.db` SQLite database with indexer API keys)
5. **qBittorrent configuration** (`qBittorrent.conf`, `BT_backup/` active torrent state)
6. **Secrets** -- database credentials, rclone backup config (new)
7. **Media files** -- already on Synology NAS, no data movement needed

### What Changes

| Aspect | Docker Compose | Kubernetes |
|---|---|---|
| Authentication | Traefik basic auth on API routes only | Authelia SSO on all ingress paths |
| Backups | None | Daily pg_dump + rclone to Cloudflare R2 (encrypted) |
| Network isolation | Docker networks (sonarr, radarr, traefik) | Kubernetes NetworkPolicies (default-deny + explicit allow) |
| Prowlarr access | Exposed on port 9696 directly | Internal only, access via `kubectl port-forward` |
| Secrets management | `stack.env.real` (plain text on disk) | SOPS-encrypted Secrets in Git |

### Config-as-Code

The *arr applications store most settings in databases and runtime-modified config files (`config.xml`), which limits config-as-code options. Here is what can and cannot be managed declaratively:

| Aspect | As Code? | Mechanism |
|---|---|---|
| Database credentials | Yes | SOPS-encrypted Secret (`secret.sops.yaml`) |
| Backup config (rclone) | Yes | SOPS-encrypted Secret (`secret-rclone.sops.yaml`) |
| Common env (PUID, TZ) | Yes | ConfigMap (`configmap.yaml`) |
| Network policies | Yes | K8s manifest (`networkpolicy.yaml`) |
| Ingress routing | Yes | K8s manifest (`ingress.yaml`) |
| Quality profiles / custom formats | Possible | [Recyclarr](https://github.com/recyclarr/recyclarr) (not yet deployed, could be added as a CronJob) |
| Sonarr/Radarr `config.xml` | No | Runtime-modified file on PVC; DB connection and API key live here |
| Prowlarr indexers | No | SQLite database on PVC; no IaC tool exists for Prowlarr |
| qBittorrent settings | No | INI file on PVC, modified at runtime |

## Target Layout

| Data | Docker Source | Container Mount | Kubernetes Resource |
|---|---|---|---|
| Sonarr PostgreSQL | `${SERVICE_DATA_ROOT_PATH}/sonarr/database` | `/var/lib/postgresql/data` | PVC `sonarr-db` (nfs-synology-ssd, 5Gi) via StatefulSet |
| Radarr PostgreSQL | `${SERVICE_DATA_ROOT_PATH}/radarr/database` | `/var/lib/postgresql/data` | PVC `radarr-db` (nfs-synology-ssd, 5Gi) via StatefulSet |
| Sonarr config | `${SERVICE_DATA_ROOT_PATH}/sonarr/config` | `/config` | PVC `sonarr-config` (nfs-synology-ssd, 5Gi) |
| Radarr config | `${SERVICE_DATA_ROOT_PATH}/radarr/config` | `/config` | PVC `radarr-config` (nfs-synology-ssd, 5Gi) |
| Prowlarr config | `${SERVICE_DATA_ROOT_PATH}/prowlarr/config` | `/config` | PVC `prowlarr-config` (nfs-synology-ssd, 1Gi) |
| qBittorrent config | `${SERVICE_DATA_ROOT_PATH}/qbittorrent/config` | `/config` | PVC `qbittorrent-config` (nfs-synology-ssd, 1Gi) |
| Media files | `${MEDIA_PATH}` | `/media` | PV `media-nfs` (manual NFS, 1Ti) + PVC `media-nfs` |
| DB credentials | `stack.env.real` | env vars | Secret `media-db-credentials` (SOPS) |
| Rclone config | N/A (new) | `/config/rclone` | Secret `rclone-config` (SOPS) |
| Common env | `stack.env.real` | env vars | ConfigMap `media-common-env` |

## Prerequisites

- `kubectl` configured for the target cluster
- `sops` and `age` installed for encrypting secrets
- SSH access to the Synology NAS (to inspect PVC backing directories and copy files)
- Docker Compose stack still running (for database dumps) or config data still accessible on NAS
- Note the following values from your Docker `stack.env.real`:
  - `SERVICE_DATA_ROOT_PATH` -- base path for app data on NAS
  - `MEDIA_PATH` -- media library path on NAS
  - `SONARR_DB_PASSWORD`, `RADARR_DB_PASSWORD` -- current database passwords

The NFS provisioner creates PVC backing directories on the NAS under `/volume3/k8s-storage/` with the naming pattern `<namespace>-<pvc-name>-<pvc-uid>/`.

## Step-by-step Migration

### Phase 1: Pre-Migration Backup

This is a safety net. The original data is not modified during migration.

1. Pause all torrents in the qBittorrent WebUI (ensures clean fastresume files in `BT_backup/`).

2. Dump both PostgreSQL databases from the running Docker containers:

   ```bash
   docker exec sonarr-db pg_dump -U sonarr -d sonarr-main --clean --if-exists > sonarr-main.sql
   docker exec radarr-db pg_dump -U radarr -d radarr-main --clean --if-exists > radarr-main.sql
   ```

3. Verify the dumps are non-empty:

   ```bash
   wc -l sonarr-main.sql radarr-main.sql
   ```

4. Copy all config directories from the NAS to a local backup:

   ```bash
   rsync -av ${SERVICE_DATA_ROOT_PATH}/sonarr/config/ ./backup/sonarr-config/
   rsync -av ${SERVICE_DATA_ROOT_PATH}/radarr/config/ ./backup/radarr-config/
   rsync -av ${SERVICE_DATA_ROOT_PATH}/prowlarr/config/ ./backup/prowlarr-config/
   rsync -av ${SERVICE_DATA_ROOT_PATH}/qbittorrent/config/ ./backup/qbittorrent-config/
   ```

> **Prowlarr SQLite:** If Prowlarr was not cleanly stopped, `prowlarr.db-wal` and `prowlarr.db-shm` files may exist alongside `prowlarr.db`. These **must** be copied together -- missing WAL files can result in data loss.

### Phase 2: Prepare Kubernetes Secrets

1. Fill in `secret.sops.yaml` with the actual database credentials. You can reuse the same passwords from `stack.env.real`:

   ```yaml
   stringData:
     SONARR_DB_USER: sonarr
     SONARR_DB_NAME: sonarr-main
     SONARR_DB_PASSWORD: <your-sonarr-db-password>
     RADARR_DB_USER: radarr
     RADARR_DB_NAME: radarr-main
     RADARR_DB_PASSWORD: <your-radarr-db-password>
   ```

2. Fill in `secret-rclone.sops.yaml` with your Cloudflare R2 credentials for backup uploads (this is new infrastructure, not migrated from Docker).

3. Encrypt both secrets:

   ```bash
   sops --encrypt --age <AGE_PUBLIC_KEY> --encrypted-regex '^(data|stringData)$' secret.yaml > secret.sops.yaml
   sops --encrypt --age <AGE_PUBLIC_KEY> --encrypted-regex '^(data|stringData)$' secret-rclone.yaml > secret-rclone.sops.yaml
   ```

4. Verify `configmap.yaml` values match the Docker stack (PUID: 1027, PGID: 100, TZ: Europe/Kyiv).

> **If you change DB passwords:** You must also update `<PostgresPassword>` in `config.xml` for Sonarr and Radarr (Phase 6b/6c), since the apps store the DB connection string in their config files.

### Phase 3: Stop Docker Compose Stack

Stop the Docker stack to prevent two instances writing to the same data.

In Portainer: Stop the media stack.

Or via CLI:

```bash
docker compose -f docker-compose.yaml --env-file stack.env.real down
```

Verify all containers are stopped. Media files on the NAS remain accessible.

### Phase 4: Deploy Kubernetes Resources (Apps Scaled to Zero)

> **Why `replicas: 0`?** Flux applies all manifests in the `apps` Kustomization at once -- there is no sub-staging within a single Kustomization. Without this, the PostgreSQL StatefulSets would start (initializing empty databases), init containers would pass as soon as the DBs accept connections, and the apps would boot against empty databases and empty config PVCs before you have a chance to migrate data.

1. In all four Deployment manifests, set `replicas: 0`:

   - `deployment-sonarr.yaml`
   - `deployment-radarr.yaml`
   - `deployment-prowlarr.yaml`
   - `deployment-qbittorrent.yaml`

2. Commit and push all manifests to the branch Flux watches:

   ```bash
   git add kubernetes/app/media/
   git commit -m "media: add media stack (apps scaled to zero for migration)"
   git push
   ```

3. Flux will reconcile the `apps` Kustomization and create everything: namespace, secrets, configmaps, PVCs, PV, StatefulSets, services, ingress, network policies, and backup CronJobs. The PostgreSQL StatefulSets will start and initialize empty databases. No app pods will be created.

4. Wait for reconciliation to complete:

   ```bash
   flux reconcile kustomization apps --with-source
   kubectl get pvc -n media
   ```

   All PVCs should be `Bound`.

5. Identify the PVC backing directories on the NAS:

   ```bash
   ssh nas "ls /volume3/k8s-storage/ | grep media"
   ```

   Note the full paths -- you will copy config files into these directories in Phase 6.

6. Verify both database pods are ready:

   ```bash
   kubectl wait --for=condition=ready pod -n media -l app=sonarr-db --timeout=120s
   kubectl wait --for=condition=ready pod -n media -l app=radarr-db --timeout=120s
   ```

### Phase 5: Migrate PostgreSQL Databases

The StatefulSets are already running from Phase 4 with empty databases. Restore the dumps from Phase 1.

1. Copy and restore the Sonarr database:

   ```bash
   kubectl cp sonarr-main.sql media/sonarr-db-0:/tmp/sonarr-main.sql
   kubectl exec -n media sonarr-db-0 -- psql -U sonarr -d sonarr-main -f /tmp/sonarr-main.sql
   ```

2. Copy and restore the Radarr database:

   ```bash
   kubectl cp radarr-main.sql media/radarr-db-0:/tmp/radarr-main.sql
   kubectl exec -n media radarr-db-0 -- psql -U radarr -d radarr-main -f /tmp/radarr-main.sql
   ```

3. Verify restoration:

   ```bash
   kubectl exec -n media sonarr-db-0 -- psql -U sonarr -d sonarr-main -c "SELECT count(*) FROM \"Series\";"
   kubectl exec -n media radarr-db-0 -- psql -U radarr -d radarr-main -c "SELECT count(*) FROM \"Movies\";"
   ```

> **Do not copy the PostgreSQL data directory directly.** Docker uses `PGDATA=/var/lib/postgresql/data` (the mount root), while the K8s StatefulSets set `PGDATA=/var/lib/postgresql/data/pgdata` (a subdirectory). A direct copy will not work. Always use `pg_dump`/`psql`.

### Phase 6: Migrate Application Configs

For each application, copy the config directory from its old NAS path to the new PVC backing directory. The NFS provisioner creates PVC directories under `/volume3/k8s-storage/` on the NAS.

All commands below are run via SSH on the NAS. Replace `<pvc-dir>` with the actual PVC directory names found in Phase 4.

#### 6a: qBittorrent

```bash
cp -a ${SERVICE_DATA_ROOT_PATH}/qbittorrent/config/* /volume3/k8s-storage/<qbittorrent-config-pvc-dir>/
chown -R 1027:100 /volume3/k8s-storage/<qbittorrent-config-pvc-dir>/
```

Verify that `qBittorrent/qBittorrent.conf` and `qBittorrent/BT_backup/` were copied. No path changes are needed -- media is mounted at `/media` in both Docker and K8s.

#### 6b: Sonarr

```bash
cp -a ${SERVICE_DATA_ROOT_PATH}/sonarr/config/* /volume3/k8s-storage/<sonarr-config-pvc-dir>/
chown -R 1027:100 /volume3/k8s-storage/<sonarr-config-pvc-dir>/
```

Review `config.xml` and verify these fields:

| Field | Expected Value | Notes |
|---|---|---|
| `<PostgresHost>` | `sonarr-db` | Matches K8s service name (same as Docker) |
| `<PostgresPort>` | `5432` | Unchanged |
| `<PostgresUser>` | `sonarr` | Must match `media-db-credentials` Secret |
| `<PostgresPassword>` | (your password) | Update if you changed the password in Phase 2 |
| `<ApiKey>` | (preserve existing) | Used by Prowlarr and external tools |
| `<AuthenticationMethod>` | Consider `External` | If relying on Authelia for WebUI auth |

#### 6c: Radarr

```bash
cp -a ${SERVICE_DATA_ROOT_PATH}/radarr/config/* /volume3/k8s-storage/<radarr-config-pvc-dir>/
chown -R 1027:100 /volume3/k8s-storage/<radarr-config-pvc-dir>/
```

Same `config.xml` review as Sonarr (6b), with `<PostgresHost>` = `radarr-db` and matching Radarr credentials.

#### 6d: Prowlarr

```bash
cp -a ${SERVICE_DATA_ROOT_PATH}/prowlarr/config/* /volume3/k8s-storage/<prowlarr-config-pvc-dir>/
chown -R 1027:100 /volume3/k8s-storage/<prowlarr-config-pvc-dir>/
```

The Prowlarr config directory contains a **SQLite database** (`prowlarr.db`) that stores all indexer configurations with their API keys, as well as Sonarr/Radarr app connection settings. If `-wal` or `-shm` files exist, they must be copied too.

Verify that the stored Sonarr/Radarr connection URLs use internal hostnames (e.g., `http://sonarr:8989`, `http://radarr:7878`) rather than external URLs. These match the K8s service names, so no changes are needed. If they use external URLs, you will need to update them in the Prowlarr UI after starting pods (Phase 7).

### Phase 7: Start Application Pods

With databases restored and configs in place, scale the apps up.

1. Change `replicas: 0` back to `replicas: 1` in all four Deployment manifests:

   - `deployment-sonarr.yaml`
   - `deployment-radarr.yaml`
   - `deployment-prowlarr.yaml`
   - `deployment-qbittorrent.yaml`

2. Commit and push:

   ```bash
   git add kubernetes/app/media/deployment-*.yaml
   git commit -m "media: scale apps to 1 after data migration"
   git push
   ```

3. Wait for Flux to reconcile and all pods to start:

   ```bash
   flux reconcile kustomization apps --with-source
   kubectl get pods -n media -w
   ```

   The init containers (`wait-for-nfs`, `wait-for-db`) will pass quickly since the databases and NFS are already available.

## Post-Migration Configuration

### Inter-Service Connections

The Docker Compose service names (`sonarr-db`, `radarr-db`, `qbittorrent`, `prowlarr`, `sonarr`, `radarr`) intentionally match the Kubernetes service names. This means most inter-service connections should work without modification:

- Sonarr/Radarr download client (qBittorrent at `qbittorrent:8114`)
- Sonarr/Radarr database connection (`sonarr-db:5432`, `radarr-db:5432`)
- Prowlarr app sync to Sonarr/Radarr

Verify by testing connections in each app's UI.

### Authentication Model Change

The Docker stack exposed **only API routes** through Traefik with basic auth:
- `Host(domain) && PathPrefix(/api/v2)` for qBittorrent
- `Host(domain) && PathPrefix(/api/v3)` for Sonarr/Radarr

The K8s stack routes **all paths** (`/`) through Authelia. This affects:
- **Mobile apps** (nzb360, LunaSea): These used direct API access with basic auth. They will now be blocked by Authelia unless configured to authenticate through it, or unless you create a separate Ingress for API routes without the Authelia middleware.
- **Prowlarr sync**: If Prowlarr syncs to Sonarr/Radarr via external URLs, those requests will hit Authelia. Internal service-to-service communication (via `http://sonarr:8989`) is unaffected.

### Prowlarr Access

Prowlarr has no Ingress in this deployment (internal-only). Access the UI via:

```bash
kubectl port-forward -n media svc/prowlarr 9696:9696
```

### Media Path Verification

Verify that `/media` inside containers maps to the correct NAS directory. Check:

- Sonarr: Settings > Media Management > Root Folders
- Radarr: Settings > Media Management > Root Folders
- qBittorrent: Default download path (should be under `/media/downloads` or similar)

## Verification

### PostgreSQL Databases

```bash
kubectl logs -n media -l app=sonarr-db --tail=20
kubectl logs -n media -l app=radarr-db --tail=20
```

No authentication errors or crash loops.

### qBittorrent

- Pod starts without errors
- Previously paused torrents appear in the list (from `BT_backup/`)
- WebUI accessible via ingress + Authelia (or port-forward)

### Sonarr

```bash
kubectl logs -n media -l app=sonarr --tail=50
```

- No database connection errors
- Series library intact (check series count matches pre-migration)
- Quality profiles and custom formats preserved
- Download client connection test passes (Settings > Download Clients)

### Radarr

Same checks as Sonarr but for movies.

### Prowlarr

```bash
kubectl port-forward -n media svc/prowlarr 9696:9696
```

- Indexers present and functional (test each)
- App connections to Sonarr/Radarr work (Settings > Apps > test)

### Backup CronJobs

Trigger a manual backup run and verify:

```bash
kubectl create job -n media --from=cronjob/sonarr-db-backup sonarr-db-backup-test
kubectl create job -n media --from=cronjob/radarr-db-backup radarr-db-backup-test
kubectl logs -n media -l job-name=sonarr-db-backup-test -f
```

Verify the dump file appears in your Cloudflare R2 bucket.

### Network Policies

Verify isolation is working:

```bash
# This should succeed (sonarr -> sonarr-db)
kubectl exec -n media deploy/sonarr -- nc -z sonarr-db 5432

# This should fail/timeout (sonarr -> radarr-db)
kubectl exec -n media deploy/sonarr -- nc -z -w2 radarr-db 5432
```

## Pitfalls and Troubleshooting

### PostgreSQL PGDATA path difference

Docker uses `PGDATA=/var/lib/postgresql/data` (the mount root). The K8s StatefulSets set `PGDATA=/var/lib/postgresql/data/pgdata` (a subdirectory). Never copy the Docker PostgreSQL data directory directly to the K8s PVC. Always use `pg_dump`/`psql`.

### Prowlarr SQLite WAL files

If `prowlarr.db-wal` and `prowlarr.db-shm` exist alongside `prowlarr.db`, all three files must be copied together. Missing WAL files causes data loss (recent indexer changes) or database corruption.

### qBittorrent active torrents

The `BT_backup/` directory contains `.torrent` and `.fastresume` files. Both are needed for torrents to resume. If Prowlarr was not paused before stopping Docker, fastresume files may be stale. Torrents will need to be force-rechecked (slow but non-destructive).

### File ownership on NFS

The NFS provisioner may create directories with root ownership. Verify that files in PVC directories have UID:GID `1027:100`:

```bash
ssh nas "ls -ln /volume3/k8s-storage/<pvc-dir>/"
```

Fix with `chown -R 1027:100 <path>` if needed.

### DB password mismatch

If the password in `media-db-credentials` Secret does not match `<PostgresPassword>` in `config.xml`, the app will fail with PostgreSQL authentication errors. Check logs:

```bash
kubectl logs -n media deploy/sonarr | grep -i "password\|auth\|postgres"
```

### API key preservation

Sonarr, Radarr, and Prowlarr each have an `<ApiKey>` in their `config.xml`. Prowlarr uses Sonarr/Radarr API keys for indexer sync. If any `config.xml` is lost or regenerated with a new API key, reconfigure all inter-service connections in the Prowlarr UI.

### Authelia blocking API access

The Ingress applies Authelia middleware to all paths (`/`). Programmatic API access (mobile apps, webhooks, external Prowlarr sync) will be blocked. Options:
- Create a separate Ingress resource for `/api/*` paths without the Authelia middleware annotation.
- Configure API clients to authenticate through Authelia.

### Media NFS path mismatch

The Docker `MEDIA_PATH` and the K8s PV `spec.nfs.path` (`${MEDIA_NFS_PATH}`) must resolve to the same NAS directory. If they differ, Sonarr/Radarr will not find existing media and may attempt to re-download. Verify by checking that `/media` inside a running pod contains the expected content:

```bash
kubectl exec -n media deploy/sonarr -- ls /media/
```

## Rollback

The original Docker data under `${SERVICE_DATA_ROOT_PATH}` is copied, not moved. To roll back:

1. Revert the media manifests from Git (or remove the media directory from the `apps` Kustomization path) and push. Flux will delete the namespace and all resources via pruning.

   Alternatively, suspend Flux and delete manually:

   ```bash
   flux suspend kustomization apps
   kubectl delete namespace media
   ```

2. Re-deploy the Docker Compose stack from Portainer with the original `stack.env.real`.
3. Resume torrents in qBittorrent.
