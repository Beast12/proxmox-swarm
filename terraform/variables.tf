variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://proxmox-1.lan:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in form 'user@pam!token=secret'"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure TLS to Proxmox API (self-signed)."
  type        = bool
  default     = true
}

variable "proxmox_nodes" {
  description = "Proxmox node names (as seen by the API)."
  type        = list(string)
}

variable "default_vm_storage" {
  description = "Datastore ID for VM disks."
  type        = string
}

variable "default_lxc_storage" {
  description = "Storage ID for LXC rootfs."
  type        = string
}

variable "snippet_storage" {
  description = "Storage ID that supports snippets/files for cloud-init user-data."
  type        = string
}

variable "lan_bridge" {
  description = "Proxmox bridge name (e.g. vmbr0)."
  type        = string
}

variable "lan_gateway" {
  description = "Default gateway for VMs/LXCs."
  type        = string
}

variable "lan_dns" {
  description = "DNS servers."
  type        = list(string)
}

variable "ssh_public_keys" {
  description = "SSH public keys injected via cloud-init."
  type        = list(string)
}

variable "swarm_managers" {
  description = "Swarm manager VM definitions."
  type = map(object({
    vmid    = number
    node    = string
    ip      = string
    cores   = number
    memory  = number
    disk_gb = number
  }))
}

variable "swarm_workers" {
  description = "Swarm worker VM definitions."
  type = map(object({
    vmid    = number
    node    = string
    ip      = string
    cores   = number
    memory  = number
    disk_gb = number
  }))
}

variable "edge_lxcs" {
  description = "Edge LXC definitions for load balancers."
  type = map(object({
    vmid    = number
    node    = string
    ip      = string
    cores   = number
    memory  = number
    disk_gb = number
  }))
}

variable "edge_vip" {
  description = "VIP for Keepalived on edge LXCs."
  type        = string
}

variable "public_domain" {
  description = "Base domain for public endpoints."
  type        = string
}

variable "acme_email" {
  description = "Email for Let's Encrypt registration."
  type        = string
}

variable "proxmox_ssh_username" {
  description = "SSH username for node access used by provider file uploads."
  type        = string
  default     = "root"
}

variable "cloud_image_datastore" {
  description = "Datastore where the cloud image file is downloaded (typically 'local' which supports ISO content)."
  type        = string
  default     = "local"
}

variable "debian_cloud_image_url" {
  description = "URL to Debian generic cloud qcow2."
  type        = string
  default     = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

variable "debian_cloud_image_file_name" {
  description = "Filename to store in Proxmox datastore."
  type        = string
  default     = "debian-13-genericcloud-amd64.img"
}
