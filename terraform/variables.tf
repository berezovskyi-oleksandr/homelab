variable "proxmox_endpoint" {
  description = "The Proxmox API endpoint URL"
  type        = string
}

variable "proxmox_api_token" {
  description = "The Proxmox API token"
  type        = string
  sensitive   = false
}

variable "clusters" {
  type = map(object({
    cores        = number
    memory       = number
    disk_size_gb = number
    hostname     = string
    mac_address  = string
    ip_address   = string
    datastore_id = string
  }))
}
