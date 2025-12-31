output "swarm_manager_ips" {
  value = { for k, m in module.swarm_manager_vms : k => m.ipv4_address }
}

output "swarm_worker_ips" {
  value = { for k, m in module.swarm_worker_vms : k => m.ipv4_address }
}

output "edge_ips" {
  value = { for k, m in module.edge_lxcs : k => m.ipv4_address }
}
