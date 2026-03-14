variable "hostname" {
  description = "Container hostname"
  type        = string
}

variable "vmid" {
  description = "Proxmox container ID"
  type        = number
}

variable "node" {
  description = "Proxmox node to place the container on (e.g. proxmox-1)"
  type        = string
}

variable "ip" {
  description = "Static IP address without CIDR prefix (e.g. 192.168.10.103)"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Memory in MB"
  type        = number
}

variable "disk_gb" {
  description = "Root disk size in GB"
  type        = number
}

variable "storage" {
  description = "Datastore ID for the root disk (e.g. local-lvm)"
  type        = string
}

variable "os_template" {
  description = "Template file ID (e.g. local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst)"
  type        = string
}

variable "lan_bridge" {
  description = "Network bridge (e.g. vmbr0)"
  type        = string
}

variable "lan_gateway" {
  description = "Default gateway"
  type        = string
}

variable "lan_dns" {
  description = "DNS server list"
  type        = list(string)
}

variable "ssh_public_keys" {
  description = "SSH public keys to inject into root"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the container"
  type        = list(string)
  default     = []
}

# NFS mounts — add entries to attach NFS shares to the container.
# Example:
#   nfs_mounts = [
#     { server = "192.168.10.10", export = "/volume1/data", mount = "/mnt/data" },
#     { server = "192.168.10.10", export = "/volume1/data2", mount = "/mnt/data2", options = "defaults,_netdev,nofail,rw" },
#   ]
variable "nfs_mounts" {
  description = "NFS shares to mount inside the container"
  type = list(object({
    server  = string
    export  = string
    mount   = string
    options = string
  }))
  default = []
}

# Host bind mounts exposed inside the container.
# `volume` is a host path on the Proxmox node.
variable "bind_mounts" {
  description = "Host bind mounts to attach into the container"
  type = list(object({
    volume    = string
    path      = string
    read_only = bool
    shared    = bool
  }))
  default = []
}
