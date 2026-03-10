# Jellyfin Migration Guide

This document describes how to migrate an existing Docker Compose Jellyfin instance to this Kubernetes deployment.

## Overview

The migration involves moving two categories of data:

1. **Config** — Jellyfin server configuration, users, plugins, metadata
2. **Cache** — Transcoding temp files, image cache

The media library itself requires no migration — the NFS PV points to the same Synology share (`/volume1/media`).

## Source Layout (Docker Compose)

| Container Path | Docker Source | Description |
|---|---|---|
| `/config` | `/home/server/docker/jellyfin/config` (bind mount) | Server config, users, plugins |
| `/config/metadata` | `synology:/volume2/jellyfin-data/metadata` (NFS, overlaid) | Library metadata |
| `/cache` | `synology:/volume2/jellyfin-data/cache` (NFS) | Transcoding cache |
| `/media` | `synology:/volume1/media/complete` (NFS) | Media files (no migration needed) |

## Target Layout (Kubernetes)

| Container Path | Kubernetes Resource | Storage |
|---|---|---|
| `/config` | PVC `jellyfin-config` | nfs-synology-ssd (under `/volume3/k8s-storage/`) |
| `/cache` | PVC `jellyfin-cache` | nfs-synology-ssd (under `/volume3/k8s-storage/`) |
| `/media` | PVC `jellyfin-media` → PV `jellyfin-media-nfs` | NFS `/volume1/media` (subPath `complete`) |

## Prerequisites

### Intel GPU for hardware transcoding

Talos Linux does not include the `i915` kernel module by default. To enable GPU passthrough:

1. **PCI passthrough in Proxmox** — Pass through the Intel GPU (e.g. UHD 770) to the Talos VM using vfio-pci.
2. **Talos i915 system extension** — Rebuild the Talos image with the `siderolabs/i915` extension via [Talos Image Factory](https://factory.talos.dev) and upgrade the node:
   ```bash
   talosctl upgrade --image factory.talos.dev/installer/<schema-id>:<talos-version>
   ```
3. **Kernel module** — Add to the Talos machine config:
   ```yaml
   machine:
     kernel:
       modules:
         - name: i915
   ```
4. **Node label** — The Intel GPU device plugin DaemonSet requires a node label (unless overridden in the HelmRelease values):
   ```bash
   kubectl label node <node> intel.feature.node.kubernetes.io/gpu=true
   ```

After a full VM stop/start, verify `/dev/dri` is populated and `gpu.intel.com/i915` appears in node capacity:

```bash
talosctl dmesg | grep -i i915
kubectl get node <node> -o jsonpath='{.status.capacity}' | grep gpu
```

## Step-by-step Migration

### 1. Deploy with replicas=0

The deployment is committed with `replicas: 0` so the PVCs are created without Jellyfin starting. Verify the PVCs are bound:

```bash
kubectl get pvc -n jellyfin
```

All three PVCs should show `Bound` status.

### 2. Find the PVC backing directories on the Synology

The `nfs-synology-ssd` provisioner creates directories under `/volume3/k8s-storage/`. Find the actual paths:

```bash
kubectl get pv $(kubectl get pvc jellyfin-config -n jellyfin -o jsonpath='{.spec.volumeName}') \
  -o jsonpath='{.spec.nfs.path}'

kubectl get pv $(kubectl get pvc jellyfin-cache -n jellyfin -o jsonpath='{.spec.volumeName}') \
  -o jsonpath='{.spec.nfs.path}'
```

These will return paths like `/volume3/k8s-storage/jellyfin-jellyfin-config-pvc-<uuid>`.

### 3. Copy config data

This is a two-step process because the Docker Compose setup overlaid `/config/metadata` from a separate NFS volume on top of the bind-mounted config directory.

The config directory is large (~18GB due to trickplay data), so we mount the target PVC's NFS path directly on the Docker host and copy locally — no intermediate temp dirs or tar pipes needed.

```bash
# Set these to the actual paths from step 2
CONFIG_PVC_PATH="/volume3/k8s-storage/<jellyfin-config-dir>"
CACHE_PVC_PATH="/volume3/k8s-storage/<jellyfin-cache-dir>"
DOCKER_HOST="server@docker-server.servers.lviv"
SYNOLOGY="oleksandr@synology.mgmt.lviv"

# Step 1: Mount the PVC NFS path on the Docker host
ssh $DOCKER_HOST "sudo mkdir -p /mnt/jellyfin-config && \
  sudo mount -t nfs synology.storage.lviv:$CONFIG_PVC_PATH /mnt/jellyfin-config"

# Step 2: Copy config directly (fast, no network round-trip for data)
ssh $DOCKER_HOST 'sudo rsync -a ~/docker/jellyfin/config/ /mnt/jellyfin-config/'

# Step 3: Overlay metadata from the old NFS volume (overwrites the
# metadata/ subdirectory with the NFS version, matching Docker behavior).
# Both paths are local to the Synology.
ssh -t $SYNOLOGY "sudo cp -a /volume2/jellyfin-data/metadata/. $CONFIG_PVC_PATH/metadata/"

# Step 4: Unmount
ssh $DOCKER_HOST 'sudo umount /mnt/jellyfin-config && sudo rmdir /mnt/jellyfin-config'
```

### 4. Copy cache data

```bash
# Both paths are local to the Synology.
ssh -t $SYNOLOGY "sudo cp -a /volume2/jellyfin-data/cache/. $CACHE_PVC_PATH/"
```

### 5. Scale up

```bash
kubectl scale deployment -n jellyfin jellyfin --replicas=1
```

### 6. Verify

```bash
# Check pod starts without errors
kubectl logs -n jellyfin -l acpp=jellyfin --tail=50

# Confirm GPU is available
kubectl exec -n jellyfin deploy/jellyfin -- ls -la /dev/dri/

# Check the web UI
kubectl get ingress -n jellyfin
```

## Verification Checklist

1. Jellyfin web UI is accessible at `https://<JELLYFIN_HOST>`
2. Existing users and login credentials work
3. Media libraries are visible and metadata is intact
4. Hardware transcoding works (play a video that requires transcoding, check logs for `Intel` or `vaapi` references)
5. OIDC authentication with Authelia works (configure after initial verification)

## Rollback

If something goes wrong, scale back to zero and the old Docker Compose instance can be started independently — no source data is modified during migration (only copied).

```bash
kubectl scale deployment -n jellyfin jellyfin --replicas=0
```
