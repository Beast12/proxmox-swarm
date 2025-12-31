variable "name" { type = string }
variable "vmid" { type = number }
variable "node_name" { type = string }

variable "storage" { type = string }
variable "cores" { type = number }
variable "memory" { type = number } # MB
variable "disk_gb" { type = number }

variable "bridge" { type = string }
variable "ip" { type = string }
variable "gateway" { type = string }
variable "dns" { type = list(string) }

variable "tags" {
  type    = list(string)
  default = []
}
