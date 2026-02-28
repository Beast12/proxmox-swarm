output "swarm_manager_ips" {
  description = "Swarm manager IP addresses"
  value = {
    for k, vm in module.swarm_manager_vms : k => {
      ip   = vm.ipv4_address
      name = vm.name
    }
  }
}

output "swarm_worker_ips" {
  description = "Swarm worker IP addresses"
  value = {
    for k, vm in module.swarm_worker_vms : k => {
      ip   = vm.ipv4_address
      name = vm.name
    }
  }
}

output "first_manager_ip" {
  description = "First manager IP for SSH/initialization"
  value       = values(module.swarm_manager_vms)[0].ipv4_address
}

output "lxc_containers" {
  description = "LXC container IPs and hostnames"
  value = {
    for name, container in module.lxc_containers : name => {
      ip       = container.ip
      hostname = container.hostname
    }
  }
}
