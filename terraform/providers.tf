provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure

  # Needed for proxmox_virtual_environment_file (snippets upload).
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
