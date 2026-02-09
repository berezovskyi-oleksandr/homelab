resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://github.com/siderolabs/talos/releases/download/v1.12.3/metal-amd64.iso"
  file_name    = "talos-v1.12.3-metal-amd64.iso"

  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_vm" "talos-vm" {
  for_each = var.clusters

  name      = "talos-${each.key}-node0"
  tags      = ["terraform", "talos", each.key]
  node_name = "pve"

  bios       = "ovmf"
  boot_order = ["scsi0", "ide3"]

  cpu {
    cores = each.value.cores
    type  = "host"
  }
  memory {
    dedicated = each.value.memory
  }

  network_device {
    mac_address = each.value.mac_address
  }

  cdrom {
    interface = "ide3"
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
  }

  disk {
    interface    = "scsi0"
    size         = each.value.disk_size_gb
    datastore_id = each.value.datastore_id
  }

  efi_disk {
    datastore_id = each.value.datastore_id
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
