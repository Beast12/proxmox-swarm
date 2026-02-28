output "id" {
  description = "Container VM ID"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ip" {
  description = "Container IP address"
  value       = var.ip
}

output "hostname" {
  description = "Container hostname"
  value       = var.hostname
}
