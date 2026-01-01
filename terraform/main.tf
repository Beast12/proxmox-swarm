module "swarm_manager_vms" {
  for_each = var.swarm_managers
  source   = "./modules/proxmox-vm"

  name                = "swarm-manager-${each.key}"
  vmid                = each.value.vmid
  node_name           = each.value.node
  datastore           = var.default_vm_storage
  snippet_ds          = var.snippet_storage
  cloud_image_file_id = proxmox_virtual_environment_download_file.debian_cloud[each.value.node].id


  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb

  bridge  = var.lan_bridge
  ip      = each.value.ip
  gateway = var.lan_gateway
  dns     = var.lan_dns

  ssh_public_keys = var.ssh_public_keys
  password_hash   = var.vm_password_hash
  tags            = concat(local.tags_common, ["role-swarm-manager"])
}

module "swarm_worker_vms" {
  for_each = var.swarm_workers
  source   = "./modules/proxmox-vm"

  name                = "swarm-worker-${each.key}"
  vmid                = each.value.vmid
  node_name           = each.value.node
  datastore           = var.default_vm_storage
  snippet_ds          = var.snippet_storage
  cloud_image_file_id = proxmox_virtual_environment_download_file.debian_cloud[each.value.node].id

  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb

  bridge  = var.lan_bridge
  ip      = each.value.ip
  gateway = var.lan_gateway
  dns     = var.lan_dns

  ssh_public_keys = var.ssh_public_keys
  password_hash   = var.vm_password_hash
  tags            = concat(local.tags_common, ["role-swarm-worker"])
}

module "edge_lxcs" {
  for_each = var.edge_lxcs
  source   = "./modules/proxmox-lxc"

  name      = "${local.name_pfx}-edge-${each.key}"
  vmid      = each.value.vmid
  node_name = each.value.node
  storage   = var.default_lxc_storage

  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb

  bridge  = var.lan_bridge
  ip      = each.value.ip
  gateway = var.lan_gateway
  dns     = var.lan_dns

  tags = concat(local.tags_common, ["role-edge"])
}
