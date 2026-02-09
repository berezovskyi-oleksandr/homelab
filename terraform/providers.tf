terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.95.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.10.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure = true
}
