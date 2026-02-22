# Immich Migration Guide

This document describes how to migrate Immich from the existing Docker Compose stack (`docker/stacks/immich/`) to this Kubernetes deployment.

## Overview

The migration involves three categories of data:

1. **PostgreSQL database** — all Immich metadata, users, albums, face recognition data, search vectors
2. **Photo library** — already on Synology NAS via NFS, no data movement needed
3. **Ephemeral state** (ML model cache, Redis/Valkey) — will be recreated automatically

Only the PostgreSQL database requires active migration. Everything else either stays in place (photos) or regenerates on first start (model cache, Valkey).

### What Changes

| Aspect | Docker Compose | Kubernetes |
|---|---|---|
| Orchestration | Docker Compose via Portainer | Helm chart via Flux CD HelmRelease |
| PostgreSQL | Container with bind mount | StatefulSet with NFS-backed PVC |
| Redis | Standalone Redis 6.2 | Valkey (Redis fork) via Helm subchart |
| Backups (photos) | resticprofile with crond inside container | K8s CronJob running resticprofile |
| Backups (database) | postgres-backup-local (hourly local dumps) | K8s CronJob: pg_dump + rclone to R2 |
| Ingress | Traefik Docker labels | K8s Ingress with cert-manager TLS |
| Secrets | `stack.env.real` (plain text on disk) | SOPS-encrypted Secrets in Git |
| Network isolation | Docker network `immich` | K8s NetworkPolicies (default-deny + explicit allow) |
| Authentication | Immich built-in | Immich built-in (unchanged, no Authelia) |

### What Stays the Same

- Photo library location on NAS (same NFS path)
- Immich PostgreSQL image with vectorchord/pgvectors extensions
- Restic backup repository on Backblaze B2 (same repo, same key — history carries over)
- Database credentials (can be reused from `stack.env.real`)

## Prerequisites

- `kubectl` configured for the target cluster
- `sops` and `age` installed for encrypting secrets
- Docker Compose stack still running (for database dump)
- Note the following values from your Docker `stack.env.real`:
  - `UPLOAD_LOCATION` — photo library path on NAS (this becomes `IMMICH_UPLOAD_NFS_PATH`)
  - `DB_PASSWORD`, `DB_USERNAME`, `DB_DATABASE_NAME` — current database credentials
- Verify which Immich version Docker is running:

  ```bash
  docker inspect immich-server --format '{{.Config.Image}}'
  ```

  The HelmRelease pins `v2.0.0`. If Docker runs a different version, update `image.tag` in `release.yaml` to match before migrating, then upgrade after migration is verified.

## Phase 1: Deploy Infrastructure (Immich Suspended)

The HelmRelease is deployed in a suspended state so that only the supporting infrastructure (database, PVCs, secrets, network policies) is created. Immich app pods will not start until Phase 3.

1. Suspend the HelmRelease by adding `spec.suspend: true` to `release.yaml`:

   ```yaml
   spec:
     suspend: true
     chart:
       ...
   ```

2. Fill in and encrypt all secrets:

   ```bash
   # Edit with actual values, then encrypt
   sops --encrypt --in-place kubernetes/app/immich/secret.sops.yaml
   sops --encrypt --in-place kubernetes/app/immich/secret-rclone.sops.yaml
   sops --encrypt --in-place kubernetes/app/immich/secret-backup.sops.yaml
   ```

3. Set `IMMICH_HOST` and `IMMICH_UPLOAD_NFS_PATH` in cluster-vars:

   ```bash
   sops kubernetes/config/cluster-vars.sops.yaml
   ```

   `IMMICH_UPLOAD_NFS_PATH` must be the same NAS path as Docker's `UPLOAD_LOCATION`.

4. Commit and push:

   ```bash
   git add kubernetes/app/immich/ kubernetes/config/cluster-vars.sops.yaml
   git commit -m "feat(k8s/immich): add immich stack (HelmRelease suspended for migration)"
   git push
   ```

5. Wait for Flux to reconcile:

   ```bash
   flux reconcile kustomization apps --with-source
   kubectl get pvc -n immich
   ```

   All PVCs should be `Bound`. The HelmRelease will show as `Suspended`.

6. Verify the database pod is ready:

   ```bash
   kubectl wait --for=condition=ready pod -n immich -l app=immich-db --timeout=120s
   ```

## Phase 2: Migrate PostgreSQL Database

The StatefulSet is running from Phase 1 with an empty database. Dump from Docker and restore into K8s.

1. Dump the database from the running Docker container:

   ```bash
   docker exec immich-database pg_dump -U immich -d immich --clean --if-exists > immich.sql
   ```

   > The container name may differ — check with `docker ps | grep postgres`. Use the container running the `ghcr.io/immich-app/postgres` image.

2. Verify the dump is non-empty:

   ```bash
   wc -l immich.sql
   grep -c "CREATE TABLE" immich.sql
   ```

3. Copy the dump into the K8s pod and restore:

   ```bash
   kubectl cp immich.sql immich/immich-db-0:/tmp/immich.sql
   kubectl exec -n immich immich-db-0 -- psql -U immich -d immich -f /tmp/immich.sql
   ```

   Some `DROP ... does not exist` notices are expected (from `--clean --if-exists`). Errors about extensions already existing are also normal.

4. Verify restoration:

   ```bash
   # Check table count
   kubectl exec -n immich immich-db-0 -- psql -U immich -d immich -c \
     "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';"

   # Check that vector extensions are present
   kubectl exec -n immich immich-db-0 -- psql -U immich -d immich -c \
     "SELECT extname, extversion FROM pg_extension WHERE extname LIKE '%vector%';"

   # Check asset count (your photo count)
   kubectl exec -n immich immich-db-0 -- psql -U immich -d immich -c \
     "SELECT count(*) FROM asset;"
   ```

5. Verify the NFS library path is correct. The photo library PV should point to the same NFS directory as Docker's `UPLOAD_LOCATION`:

   ```bash
   kubectl get pv immich-library -o jsonpath='{.spec.nfs.path}'
   ```

## Phase 3: Start Immich

With the database restored and NFS path verified, unsuspend the HelmRelease.

1. Remove `suspend: true` from `release.yaml`.

2. Commit and push:

   ```bash
   git add kubernetes/app/immich/release.yaml
   git commit -m "feat(k8s/immich): unsuspend HelmRelease after data migration"
   git push
   ```

3. Wait for Flux to deploy the Helm chart:

   ```bash
   flux reconcile kustomization apps --with-source
   kubectl get helmrelease -n flux-system immich
   kubectl get pods -n immich -w
   ```

   You should see pods for: `immich-server`, `immich-machine-learning`, `immich-valkey-master`, and `immich-db-0` (already running).

4. The ML service will download models on first start — this is expected and may take several minutes.

## Post-Migration Verification

### Web Access

Open `https://<IMMICH_HOST>` in a browser. You should see the Immich login page with your existing users.

### Photo Library

- Log in and verify your photos and albums are visible
- Check that thumbnails load (they're stored in the upload directory)
- Verify face recognition data is intact (People tab)

### Ingress and TLS

```bash
kubectl get ingress -n immich
kubectl get certificate -n immich
```

The certificate should show `Ready: True` after cert-manager provisions it.

### Backup CronJobs

Trigger manual test runs:

```bash
# Test database backup
kubectl create job -n immich --from=cronjob/immich-db-backup immich-db-backup-test
kubectl logs -n immich -l job-name=immich-db-backup-test -f

# Test library backup (resticprofile)
kubectl create job -n immich --from=cronjob/immich-library-backup immich-library-backup-test
kubectl logs -n immich -l job-name=immich-library-backup-test -f
```

The library backup should connect to the existing Backblaze B2 restic repository and complete an incremental backup.

### Network Policies

```bash
# Verify immich-server can reach the database
kubectl exec -n immich deploy/immich-server -- nc -z immich-db 5432
```

## Stop Docker Compose Stack

Only after K8s is verified working:

In Portainer: Stop the immich stack.

Or via CLI:

```bash
docker compose -f docker-compose.yaml --env-file stack.env.real down
```

The photo library on the NAS remains accessible via the K8s NFS PV.

## Rollback

The Docker data is not modified during migration (pg_dump reads only, NFS path is shared). To roll back:

1. Revert the immich manifests from Git and push. Flux will delete the namespace and all resources via pruning.

   Alternatively, suspend Flux and delete manually:

   ```bash
   flux suspend kustomization apps
   kubectl delete namespace immich
   ```

2. Re-deploy the Docker Compose stack from Portainer with the original `stack.env.real`.

## Pitfalls and Troubleshooting

### PostgreSQL PGDATA path difference

Docker uses `PGDATA=/var/lib/postgresql/data` (the mount root). The K8s StatefulSet sets `PGDATA=/var/lib/postgresql/data/pgdata` (a subdirectory). Never copy the Docker PostgreSQL data directory directly to the K8s PVC. Always use `pg_dump`/`psql`.

### Immich version mismatch

If Docker was running a different Immich version than the one pinned in the HelmRelease (`v2.0.0`), Immich may run database migrations on startup. This is normally fine (Immich handles forward migrations), but there is no rollback path for schema changes. Match versions first if unsure.

### NFS path mismatch

`IMMICH_UPLOAD_NFS_PATH` must resolve to exactly the same NAS directory as Docker's `UPLOAD_LOCATION`. If it differs, Immich will start but show no photos, and thumbnails will be broken. Verify by checking inside a running pod:

```bash
kubectl exec -n immich deploy/immich-server -- ls /usr/src/app/upload/
```

You should see directories like `library/`, `thumbs/`, `encoded-video/`, `upload/`, `profile/`.

### vectorchord/pgvectors extensions

The K8s StatefulSet uses the same custom PostgreSQL image (`ghcr.io/immich-app/postgres:14-vectorchord0.3.0-pgvectors0.2.0`) as Docker. Extensions are installed during `initdb` and preserved through `pg_dump`/`psql` restore. If you see errors about missing `vector` type, verify the extensions:

```bash
kubectl exec -n immich immich-db-0 -- psql -U immich -d immich -c "SELECT extname FROM pg_extension;"
```

### Restic lock errors

If the Docker resticprofile container was not cleanly stopped, a stale lock may exist in the Backblaze B2 restic repository. The K8s CronJob will fail with a lock error. Fix by running:

```bash
kubectl create job -n immich --from=cronjob/immich-library-backup immich-unlock-test --dry-run=client -o yaml | \
  sed 's/backup && resticprofile.*forget/unlock/' | kubectl apply -f -
```

Or exec into a temporary pod with the restic key and AWS credentials and run `restic unlock`.
