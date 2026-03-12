# Terraform — Cluster Provisioning

Provisions a Talos Linux VM on Proxmox and bootstraps the Kubernetes control plane.

## What It Does

1. Downloads the Talos ISO to Proxmox local storage
2. Creates a VM per entry in `var.clusters` (UEFI, SCSI disk, host CPU passthrough)
3. Generates Talos machine secrets and applies the machine configuration
4. Bootstraps the Talos cluster and waits for health check
5. Outputs `kubeconfig` and `talosconfig` for cluster access

## Providers

| Provider | Version |
|----------|---------|
| `bpg/proxmox` | 0.95.0 |
| `siderolabs/talos` | 0.10.1 |

## Variables

Configured via `terraform.tfvars` (gitignored):

| Variable | Description |
|----------|-------------|
| `proxmox_endpoint` | Proxmox API URL (e.g. `https://pve:8006`) |
| `proxmox_api_token` | Proxmox API token (`user@realm!token=secret`) |
| `clusters` | Map of cluster definitions (see below) |

Each entry in `clusters`:

```hcl
clusters = {
  homelab = {
    cores        = 8
    memory       = 16384
    disk_size_gb = 100
    hostname     = "talos.example.com"
    mac_address  = "BC:24:11:xx:xx:xx"
    ip_address   = "192.168.1.x"
    datastore_id = "local-lvm"
  }
}
```

## Usage

```sh
terraform init
terraform apply

# Write kubeconfig
terraform output -json kubeconfig | jq -r '.homelab' > ~/.kube/config

# Write talosconfig
terraform output -json talosconfig | jq -r '.homelab' > ~/.talos/config
```

## Talos Factory Image

The ISO is built via [Talos Image Factory](https://factory.talos.dev) with a custom schematic that includes:
- **QEMU guest agent** (`qemu-guest-agent` system extension)
- **i915** Intel iGPU firmware extension

**Schematic ID:** `aa948be975ffec096205160edd988ee6d949d72c20a39ca5844fc0a2a3fc8415`

**Installer reference:** `factory.talos.dev/metal-installer/aa948be975ffec096205160edd988ee6d949d72c20a39ca5844fc0a2a3fc8415:v1.12.5`

Download URL pattern:
```
https://factory.talos.dev/image/<schematic-id>/<version>/metal-amd64.iso
```

## Notes

- The Talos ISO resource has `prevent_destroy = true` to avoid accidental re-download
- Control plane node has `allowSchedulingOnControlPlanes = true` (single-node cluster)
- State files (`terraform.tfstate`, `terraform.tfstate.backup`, `terraform.tfvars`, `talosconfig`) are gitignored
- `gpu_mapping` is optional per cluster; omit it to skip PCI passthrough

## Next Steps

Once `terraform apply` completes and you have a working kubeconfig, proceed to
[`kubernetes/README.md`](../kubernetes/README.md) to bootstrap Flux CD onto the cluster.
