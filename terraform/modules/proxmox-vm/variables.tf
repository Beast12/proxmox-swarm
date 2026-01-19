variable "name" {
  description = "VM name"
  type        = string
}

variable "vmid" {
  description = "VM ID"
  type        = number
}

variable "node_name" {
  description = "Proxmox node"
  type        = string
}

variable "datastore" {
  description = "VM disk storage"
  type        = string
}

variable "snippet_ds" {
  description = "Cloud-init snippet storage"
  type        = string
}

variable "cloud_image_import_id" {
  description = "Cloud image file ID for import"
  type        = string
}

variable "cores" {
  description = "CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_gb" {
  description = "Disk size in GB"
  type        = number
}

variable "bridge" {
  description = "Network bridge"
  type        = string
}

variable "ip" {
  description = "IP address"
  type        = string
}

variable "gateway" {
  description = "Gateway"
  type        = string
}

variable "dns" {
  description = "DNS servers"
  type        = list(string)
}

variable "ssh_public_keys" {
  description = "SSH public keys"
  type        = list(string)
}

variable "password_hash" {
  description = "Password hash"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "VM tags"
  type        = list(string)
  default     = []
}

variable "machine_type" {
  description = "Machine type (pc or q35 for GPU passthrough)"
  type        = string
  default     = "pc"
}

variable "gpu_passthrough" {
  description = "Enable Intel Arc GPU passthrough"
  type        = bool
  default     = false
}
