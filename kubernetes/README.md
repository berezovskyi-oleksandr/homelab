# Kubernetes Cluster Bootstrap

This covers **phase 2** of the full cluster setup. The two phases are:

1. **Terraform** (`terraform/`) — provisions the Talos VM on Proxmox and bootstraps the Kubernetes control plane. Outputs `kubeconfig` and `talosconfig`.
2. **Flux CD** (this file) — installs the GitOps controller into the running cluster and points it at this repository. From that point on, everything in `kubernetes/` is reconciled automatically.

If you haven't run Terraform yet, start with [`terraform/README.md`](../terraform/README.md).

## Prerequisites

- `flux` CLI installed
- AGE private key for SOPS decryption
- `kubectl` configured with the cluster kubeconfig from Terraform:
  ```sh
  cd ../terraform
  terraform output -json kubeconfig | jq -r '.homelab' > ~/.kube/config
  ```

## Bootstrap Steps

### 1. Verify cluster access

```sh
kubectl get nodes
```

### 2. Bootstrap Flux CD

```sh
flux bootstrap github \
  --owner=berezovskyi-oleksandr \
  --repository=homelab \
  --branch=homelab-v2 \
  --path=./kubernetes \
  --token-auth \
  --personal
```

You will be prompted for a GitHub PAT, or set it beforehand:

```sh
export GITHUB_TOKEN=<your-pat>
```

Create a fine-grained PAT scoped to the `homelab` repository with:
- **Contents**: Read and write
- **Metadata**: Read-only (granted automatically)

This installs the Flux controllers and creates the `flux-system` namespace.

### 3. Create the SOPS AGE secret

Flux needs the AGE private key to decrypt SOPS-encrypted secrets.

```sh
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=<path-to-age.key>
```

### 4. Verify Flux is reconciling

```sh
flux get kustomizations --watch
```

All kustomizations should eventually show as `Ready`.

### 5. Troubleshooting

Check Flux controller logs:

```sh
flux logs
```

Force a reconciliation:

```sh
flux reconcile source git flux-system
flux reconcile kustomization flux-system
```

## Changing the Target Branch

To point Flux at a different branch (e.g. after merging `homelab-v2` into `master`):

1. Merge the branch as usual via a PR.
2. Re-run `flux bootstrap` with the new `--branch` value:

```sh
flux bootstrap github \
  --owner=berezovskyi-oleksandr \
  --repository=homelab \
  --branch=master \
  --path=./kubernetes \
  --token-auth \
  --personal
```

This updates both the `GitRepository` resource in the cluster and the `flux-system/gotk-sync.yaml` file committed to the repo. No manual `kubectl patch` needed.

## Reconciliation Order

Flux applies resources in dependency order:

1. **config** — Cluster-wide variables and encrypted secrets
2. **infrastructure-controllers** — Traefik, cert-manager, Authelia, MetalLB, NFS provisioner, Intel GPU plugin (depends on config)
3. **infrastructure-configs** — ClusterIssuer, MetalLB config (depends on infrastructure-controllers)
4. **external-vars** — External service variables (e.g. Home Assistant)
5. **apps** — All application workloads (depends on config + infrastructure-configs + external-vars)
