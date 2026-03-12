resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  # Factory image with QEMU guest agent + i915 (Intel iGPU) extensions
  # Schematic: aa948be975ffec096205160edd988ee6d949d72c20a39ca5844fc0a2a3fc8415
  url       = "https://factory.talos.dev/image/aa948be975ffec096205160edd988ee6d949d72c20a39ca5844fc0a2a3fc8415/v1.12.5/metal-amd64.iso"
  file_name = "talos-v1.12.5-factory-metal-amd64.iso"

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_vm" "talos-vm" {
  for_each = var.clusters

  name      = "talos-${each.key}-node0"
  tags      = ["terraform", "talos", each.key]
  node_name = "pve"
  on_boot   = true

  bios       = "ovmf"
  machine    = "i440fx"
  boot_order = ["scsi0", "ide3"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }
  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
    type    = "virtio"
  }

  network_device {
    mac_address = each.value.mac_address
    firewall    = false
  }

  cdrom {
    interface = "ide3"
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
  }

  disk {
    interface    = "scsi0"
    size         = each.value.disk_size_gb
    datastore_id = each.value.datastore_id
    aio          = "io_uring"
    cache        = "none"
    discard      = "on"
    ssd          = true
  }

  efi_disk {
    datastore_id      = each.value.datastore_id
    pre_enrolled_keys = false
  }

  dynamic "hostpci" {
    for_each = each.value.gpu_mapping != null ? [each.value.gpu_mapping] : []
    content {
      device  = "hostpci0"
      mapping = hostpci.value
    }
  }

  serial_device {
    device = "socket"
  }
}

resource "talos_machine_secrets" "secrets" {
  for_each = var.clusters
}

data "talos_machine_configuration" "machine-config" {
  for_each = var.clusters

  cluster_name     = "talos-${each.key}"
  machine_type     = "controlplane"
  cluster_endpoint = "https://${each.value.hostname}:6443"
  machine_secrets  = talos_machine_secrets.secrets[each.key].machine_secrets

  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    })
  ]
}

resource "talos_machine_configuration_apply" "talos-config" {
  depends_on = [proxmox_virtual_environment_vm.talos-vm]

  for_each = var.clusters

  node                        = each.value.hostname
  client_configuration        = talos_machine_secrets.secrets[each.key].client_configuration
  machine_configuration_input = data.talos_machine_configuration.machine-config[each.key].machine_configuration
}

resource "talos_machine_bootstrap" "talos-bootstrap" {
  depends_on = [talos_machine_configuration_apply.talos-config]

  for_each = var.clusters

  node                 = each.value.hostname
  client_configuration = talos_machine_secrets.secrets[each.key].client_configuration
}

data "talos_cluster_health" "talos-health" {
  depends_on = [talos_machine_bootstrap.talos-bootstrap]

  for_each = var.clusters

  client_configuration = talos_machine_secrets.secrets[each.key].client_configuration
  control_plane_nodes  = [each.value.ip_address]
  endpoints            = [each.value.hostname]
}

data "talos_client_configuration" "talos-client-config" {
  depends_on = [data.talos_cluster_health.talos-health]

  for_each = var.clusters

  cluster_name         = each.key
  client_configuration = talos_machine_secrets.secrets[each.key].client_configuration
  nodes                = [each.value.ip_address]

}

resource "talos_cluster_kubeconfig" "talos-kubeconfig" {
  depends_on = [data.talos_cluster_health.talos-health]

  for_each = var.clusters

  client_configuration = talos_machine_secrets.secrets[each.key].client_configuration
  node                 = each.value.ip_address
}
