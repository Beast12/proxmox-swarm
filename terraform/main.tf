# ==============================================================================
# LOCALS
# ==============================================================================
locals {
  env         = terraform.workspace
  name_prefix = "swarm-${local.env}"

  tags_common = [
    "managed-by-terraform",
    "env-${local.env}",
  ]
}

# ==============================================================================
# SWARM MANAGERS
# ==============================================================================
module "swarm_manager_vms" {
  for_each = var.swarm_managers
  source   = "./modules/proxmox-vm"

  name                = "swarm-manager-${each.key}"
  vmid                = each.value.vmid
  node_name           = each.value.node
  datastore           = var.default_vm_storage
  snippet_ds          = var.snippet_storage
  template_vm_id      = var.template_vm_id
  template_vm_node_name = var.template_vm_node

  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb

  bridge  = var.lan_bridge
  ip      = each.value.ip
  gateway = var.lan_gateway
  dns     = var.lan_dns

  ssh_public_keys = var.ssh_public_keys
  password_hash   = var.vm_password_hash
  tags            = concat(local.tags_common, ["role-manager"])

  # Managers don't need GPU
  machine_type    = "pc"
  gpu_passthrough = false
}

# ==============================================================================
# SWARM WORKERS
# ==============================================================================
module "swarm_worker_vms" {
  for_each = var.swarm_workers
  source   = "./modules/proxmox-vm"

  name                = "swarm-worker-${each.key}"
  vmid                = each.value.vmid
  node_name           = each.value.node
  datastore           = var.default_vm_storage
  snippet_ds          = var.snippet_storage
  template_vm_id      = var.template_vm_id
  template_vm_node_name = var.template_vm_node

  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb

  bridge  = var.lan_bridge
  ip      = each.value.ip
  gateway = var.lan_gateway
  dns     = var.lan_dns

  ssh_public_keys = var.ssh_public_keys
  password_hash   = var.vm_password_hash
  tags            = concat(local.tags_common, ["role-worker"])

  # GPU passthrough configuration
  machine_type    = each.value.gpu_passthrough ? "q35" : "pc"
  gpu_passthrough = each.value.gpu_passthrough
}

# ==============================================================================
# DIRECTORIES ON NFS
# ==============================================================================
locals {
  swarm_data_dirs = [
    "authentik",
    "development-tools",
    "dockhand",
    "env-files",
    "komodo",
    "monitoring",
    "portainer",
    "portainer-backups",
    "services",
    "tools",
    "traefik"
  ]

  # Use first manager for directory creation
  target_manager_ip = values(module.swarm_manager_vms)[0].ipv4_address
  ssh_user          = "koen" # Update with your user
}

resource "null_resource" "swarm_data_directories" {
  for_each = toset(local.swarm_data_dirs)

  connection {
    type = "ssh"
    host = local.target_manager_ip
    user = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /mnt/proxmox_swarm_data/${each.key}",
      "sudo chown -R 1000:1000 /mnt/proxmox_swarm_data/${each.key}"
    ]
  }

  depends_on = [module.swarm_manager_vms]
}
