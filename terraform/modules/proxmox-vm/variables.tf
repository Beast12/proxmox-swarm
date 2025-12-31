variable "name" { type = string }
variable "vmid" { type = number }
variable "node_name" { type = string }

variable "datastore" { type = string }
variable "snippet_ds" { type = string }

variable "cores" { type = number }
variable "memory" { type = number } # MB
variable "disk_gb" { type = number }

variable "bridge" { type = string }
variable "ip" { type = string }
variable "gateway" { type = string }
variable "dns" { type = list(string) }

variable "ssh_public_keys" { type = list(string) }

variable "tags" {
  type    = list(string)
  default = []
}
variable "cloud_image_file_id" {
  description = "File ID of the downloaded cloud image (e.g. local:iso/debian-13-genericcloud-amd64.img)."
  type        = string
}
