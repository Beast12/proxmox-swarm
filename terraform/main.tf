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
# CLOUD IMAGE DOWNLOAD
# ==============================================================================
resource "proxmox_virtual_environment_download_file" "debian_cloud" {
  for_each = toset(var.proxmox_nodes)

  node_name    = each.key
  content_type = "iso"
  datastore_id = var.cloud_image_datastore
  file_name    = "debian-12-genericcloud-amd64.img"
  url          = var.debian_cloud_image_url
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
