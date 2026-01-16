output "vm_id" {
  description = "VM ID"
  value       = proxmox_virtual_environment_vm.this.id
}

output "ipv4_address" {
  description = "VM IP address"
  value       = var.ip
}

output "name" {
  description = "VM name"
  value       = var.name
}
