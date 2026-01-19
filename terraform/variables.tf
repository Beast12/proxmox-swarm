# ==============================================================================
# PROXMOX CONNECTION
# ==============================================================================
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow insecure TLS"
  type        = bool
  default     = true
}

variable "proxmox_nodes" {
  description = "Proxmox node names"
  type        = list(string)
}

variable "proxmox_ssh_username" {
  description = "SSH username for file uploads"
  type        = string
  default     = "root"
}

# ==============================================================================
# STORAGE
# ==============================================================================
variable "default_vm_storage" {
  description = "VM disk storage"
  type        = string
}

variable "cloud_image_storage" {
  description = "Storage for downloaded cloud images (must support import content type)"
  type        = string
}

variable "snippet_storage" {
  description = "Cloud-init snippet storage"
  type        = string
}

variable "ubuntu_cloud_image_url" {
  description = "Ubuntu cloud image URL"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}


# ==============================================================================
# NETWORK
# ==============================================================================
variable "lan_bridge" {
  description = "Network bridge"
  type        = string
}

variable "lan_gateway" {
  description = "Default gateway"
  type        = string
}

variable "lan_dns" {
  description = "DNS servers"
  type        = list(string)
}

# ==============================================================================
# SSH & AUTH
# ==============================================================================
variable "ssh_public_keys" {
  description = "SSH public keys for cloud-init"
  type        = list(string)
}

variable "vm_password_hash" {
  description = "SHA-512 password hash"
  type        = string
  sensitive   = true
}

# ==============================================================================
# DOMAIN
# ==============================================================================
variable "public_domain" {
  description = "Base domain"
  type        = string
}

variable "acme_email" {
  description = "Let's Encrypt email"
  type        = string
}

# ==============================================================================
# VM DEFINITIONS
# ==============================================================================
variable "swarm_managers" {
  description = "Swarm manager VMs"
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
  description = "Swarm worker VMs"
  type = map(object({
    vmid            = number
    node            = string
    ip              = string
    cores           = number
    memory          = number
    disk_gb         = number
    gpu_passthrough = bool
  }))
}
