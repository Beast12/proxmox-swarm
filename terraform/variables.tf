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
  description = "Ubuntu cloud image source URL for downloading new pinned images"
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
# DOCKER
# ==============================================================================
variable "docker_host" {
  description = "Docker host for network management (e.g. unix:///var/run/docker.sock or tcp://host:2376)"
  type        = string
}

variable "docker_networks" {
  description = "Docker networks to create"
  type        = list(string)
  default     = []
}

# ==============================================================================
# KEEPALIVED VIP
# ==============================================================================
variable "vip_address" {
  description = "Virtual IP address (CIDR) for keepalived"
  type        = string
}

variable "vip_interface" {
  description = "Network interface for keepalived (e.g. ens18)"
  type        = string
  default     = "ens18"
}

variable "vip_router_id" {
  description = "VRRP virtual router ID"
  type        = number
  default     = 51
}

variable "vip_auth_pass" {
  description = "VRRP authentication password (max 8 chars)"
  type        = string
  sensitive   = true
}

# ==============================================================================
# CIFS MOUNT: HOME ASSISTANT CONFIG
# ==============================================================================
variable "ha_smb_username" {
  description = "SMB username for Home Assistant share"
  type        = string
  sensitive   = true
}

variable "ha_smb_password" {
  description = "SMB password for Home Assistant share"
  type        = string
  sensitive   = true
}

variable "ha_smb_domain" {
  description = "SMB domain for Home Assistant share"
  type        = string
  default     = "WORKGROUP"
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

# ==============================================================================
# LXC CONTAINERS
# ==============================================================================
variable "lxc_template_storage" {
  description = "Datastore to download the Debian LXC template onto each node (must support vztmpl content)"
  type        = string
  default     = "local"
}

variable "debian_lxc_template_url" {
  description = "Pinned Debian LXC template URL from the Proxmox image repository"
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "lxc_containers" {
  description = "LXC containers to create on Proxmox nodes"
  type = map(object({
    vmid    = number
    node    = string
    ip      = string
    cores   = number
    memory  = number
    disk_gb = number
    storage = optional(string) # omit to use default_vm_storage
    nfs_mounts = optional(list(object({
      server  = string
      export  = string
      mount   = string
      options = optional(string, "defaults,_netdev,nofail")
    })), [])
  }))
  default = {}
}
