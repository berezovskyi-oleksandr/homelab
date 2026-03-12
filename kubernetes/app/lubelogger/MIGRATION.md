# LubeLogger Migration: Docker → Kubernetes

## Overview

LubeLogger is migrated from a single Docker container using LiteDB (SQLite-like embedded DB) to
Kubernetes with PostgreSQL as the data store. The migration involves:

1. Copying app data (images, documents, config) from the Docker host to NFS
2. Running the built-in database migration UI to import records from LiteDB → PostgreSQL

## Source Layout (Docker)

| Container Path | Docker Source |
|---|---|
| `/App/data` | `/home/server/docker/lubelogger/data` on Docker host |
| `/root/.aspnet/DataProtection-Keys` | `/home/server/docker/lubelogger/keys` on Docker host |

The `/App/data` directory contains:
- `cartracker.db` — LiteDB database with all vehicle/maintenance records
- `images/` — uploaded vehicle images
- `documents/` — uploaded maintenance documents

## Target Layout (Kubernetes)

| Container Path | Kubernetes PVC |
|---|---|
| `/App/data` | `lubelogger-data` PVC → NFS `/volume3/k8s-storage/lubelogger-data` |
| `/root/.aspnet/DataProtection-Keys` | ephemeral (pod filesystem) — losing keys only invalidates sessions |

PostgreSQL data is managed by the `lubelogger-db` StatefulSet with its own `nfs-synology-ssd` PVC.

## Prerequisites

- NFS directory created on Synology: `/volume3/k8s-storage/lubelogger-data`
- Secrets filled in and encrypted (see TODO.md)
- PostgreSQL restic repos initialized on Synology and B2

## Step-by-Step Migration

### 1. Deploy with replicas: 0

Ensure `statefulset-db.yaml` has `replicas: 1` (PostgreSQL must be running) but set the
LubeLogger Helm release to `replicaCount: 0` before the first commit. After Flux applies,
all PVCs will be created and bound.

Actually: PostgreSQL starts at replicas: 1. The app (HelmRelease) starts at replicas: 1 by default
from the chart. Since we want to run the migration UI, we need the app running. Scale to 1 normally.

### 2. Wait for PVCs to bind

```bash
kubectl get pvc -n lubelogger
```

All should be `Bound`. The `lubelogger-data` PVC binds to the static NFS PV automatically.

The PostgreSQL PVC name is `data-lubelogger-db-0` (StatefulSet volumeClaimTemplate naming).

### 3. Stop Docker service

```bash
# On the Docker host
cd /path/to/lubelogger-compose
docker compose stop app
# Keep DB stopped too since we're going to PostgreSQL
```

### 4. Copy app data to NFS

```bash
# Create the NFS directory on Synology if not done already
mkdir -p /volume3/k8s-storage/lubelogger-data

# Copy from Docker host to Synology NFS path
# Run from the Docker host (or any machine with SSH access to both):
rsync -av /home/server/docker/lubelogger/data/ synology:/volume3/k8s-storage/lubelogger-data/
```

The `cartracker.db` file is copied too — it's needed for the migration step.

### 5. Run the LiteDB → PostgreSQL migration

Once the Kubernetes app is running and PostgreSQL is ready:

```bash
# Verify LubeLogger pod is running
kubectl get pods -n lubelogger

# Verify PostgreSQL is up
kubectl exec -n lubelogger lubelogger-db-0 -- psql -U lubelogger -c '\l'
```

Navigate to `https://lubelogger.berezovskyi.dev/migration` in your browser.

1. Click **"Import to Postgres"**
2. Upload the `cartracker.db` file from your local copy of `/home/server/docker/lubelogger/data/`
3. LubeLogger will import all records automatically

### 6. Verify migration

- Check all vehicles appear
- Check maintenance records
- Check images and documents load
- Log in via Authelia OIDC

## Verification Checklist

- [ ] All pods running: `kubectl get pods -n lubelogger`
- [ ] LubeLogger web UI loads at `https://lubelogger.berezovskyi.dev`
- [ ] Authelia OIDC login works
- [ ] All vehicles visible with correct data
- [ ] Maintenance history records intact
- [ ] Images load (stored in NFS `/App/data/images/`)
- [ ] Documents accessible
- [ ] Test backup: `kubectl create job -n lubelogger --from=cronjob/lubelogger-db-backup test-db-backup`

## Rollback

1. Scale HelmRelease to 0: edit `release.yaml` → `replicaCount: 0`, commit, push
2. Restart Docker service: `docker compose start app`
3. The Docker install still has its LiteDB database intact

## Notes

- The Authelia OIDC client was already configured at `lubelogger.berezovskyi.dev` — no changes needed
- DataProtection keys are intentionally ephemeral: users will need to log in again after pod restarts
- After confirming the migration is complete, the `cartracker.db` in the NFS data directory can be deleted (it is no longer used once PostgreSQL is the backend)
