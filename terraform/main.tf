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

  swarm_nodes = toset(distinct(concat(
    [for manager in values(var.swarm_managers) : manager.node],
    [for worker in values(var.swarm_workers) : worker.node]
  )))

  cloud_image_download_node   = sort(tolist(local.swarm_nodes))[0]
  ubuntu_cloud_image_filename = replace(basename(var.ubuntu_cloud_image_url), ".img", ".qcow2")

  lxc_nodes = toset(distinct([for lxc in values(var.lxc_containers) : lxc.node]))

  manager_keys = sort(keys(var.swarm_managers))
  keepalived_priority = {
    for idx, key in local.manager_keys : key => 150 - (idx * 20)
  }
  keepalived_state = {
    for idx, key in local.manager_keys : key => idx == 0 ? "MASTER" : "BACKUP"
  }
  keepalived_peer_ips = {
    for key, manager in var.swarm_managers :
    key => [for other_key, other in var.swarm_managers : other.ip if other_key != key]
  }
  keepalived_config = {
    for key in local.manager_keys :
    key => templatefile("${path.module}/templates/keepalived.conf.tmpl", {
      state       = local.keepalived_state[key]
      interface   = var.vip_interface
      router_id   = var.vip_router_id
      priority    = local.keepalived_priority[key]
      src_ip      = var.swarm_managers[key].ip
      peer_ips    = local.keepalived_peer_ips[key]
      auth_pass   = var.vip_auth_pass
      vip_address = var.vip_address
    })
  }
}

# ==============================================================================
# CLOUD IMAGE DOWNLOADS
# ==============================================================================
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  node_name    = local.cloud_image_download_node
  datastore_id = var.cloud_image_storage
  content_type = "import"
  overwrite    = false

  url       = var.ubuntu_cloud_image_url
  file_name = local.ubuntu_cloud_image_filename
}

# ==============================================================================
# SWARM MANAGERS
# ==============================================================================
module "swarm_manager_vms" {
  for_each = var.swarm_managers
  source   = "./modules/proxmox-vm"

  name                  = "swarm-manager-${each.key}"
  vmid                  = each.value.vmid
  node_name             = each.value.node
  datastore             = var.default_vm_storage
  snippet_ds            = var.snippet_storage
  cloud_image_import_id = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id

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

  name                  = "swarm-worker-${each.key}"
  vmid                  = each.value.vmid
  node_name             = each.value.node
  datastore             = var.default_vm_storage
  snippet_ds            = var.snippet_storage
  cloud_image_import_id = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id

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
    "bar-assistant",
    "development-tools",
    "dockhand",
    "env-files",
    "ha-tools",
    "jellyfin",
    "komodo",
    "monitoring",
    "music-assistant",
    "plex",
    "portainer",
    "portainer-backups",
    "services",
    "tools",
    "traefik"
  ]

  # Use first manager for directory creation
  target_manager_ip = values(module.swarm_manager_vms)[0].ipv4_address
  ssh_user          = "koen" # Update with your user

  all_node_ips = concat(
    [for manager in values(var.swarm_managers) : manager.ip],
    [for worker in values(var.swarm_workers) : worker.ip]
  )

  plex_media_mounts = [
    { src = "192.168.10.9:/volume1/Movies", dest = "/mnt/nfs/media-nas/movies" },
    { src = "192.168.10.9:/volume1/Series", dest = "/mnt/nfs/media-nas/tv" },
    { src = "192.168.10.9:/volume1/Music", dest = "/mnt/nfs/media-nas/music" },
    { src = "192.168.10.9:/volume1/Cartoons", dest = "/mnt/nfs/media-nas/cartoons" },
    { src = "192.168.10.9:/volume1/Comedy", dest = "/mnt/nfs/media-nas/comedy" },
    { src = "192.168.10.9:/volume1/Audiobooks", dest = "/mnt/nfs/media-nas/audiobooks" },
    { src = "192.168.10.9:/volume1/Comics", dest = "/mnt/nfs/media-nas/comics" }
  ]
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
      "if [ ! -d /mnt/proxmox_swarm_data/${each.key} ]; then sudo mkdir -p /mnt/proxmox_swarm_data/${each.key}; fi",
      "if [ -d /mnt/proxmox_swarm_data/${each.key} ]; then sudo chown -R 1000:1000 /mnt/proxmox_swarm_data/${each.key} || true; fi"
    ]
  }

  depends_on = [module.swarm_manager_vms]
}

# ==============================================================================
# NFS MOUNT: POSTGRES BACKUPS
# ==============================================================================
resource "null_resource" "postgres_backups_mount" {
  for_each = toset(local.all_node_ips)

  connection {
    type = "ssh"
    host = each.key
    user = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /mnt/postgres-backups",
      "grep -q '^192\\.168\\.10\\.10:/volume1/postgresql_backups /mnt/postgres-backups nfs' /etc/fstab || echo '192.168.10.10:/volume1/postgresql_backups /mnt/postgres-backups nfs defaults 0 0' | sudo tee -a /etc/fstab > /dev/null",
      "sudo mount /mnt/postgres-backups || sudo mount -a"
    ]
  }

  depends_on = [module.swarm_manager_vms, module.swarm_worker_vms]
}

# ==============================================================================
# CIFS MOUNT: HOME ASSISTANT CONFIG
# ==============================================================================
resource "null_resource" "ha_config_mount" {
  for_each = toset(local.all_node_ips)

  connection {
    type = "ssh"
    host = each.key
    user = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /mnt/ha-config",
      "sudo install -d -m 700 /root",
      "sudo apt-get update -y",
      "sudo apt-get install -y cifs-utils",
      "cat <<'EOF' | sudo tee /root/.smb-ha > /dev/null\nusername=${var.ha_smb_username}\npassword=${var.ha_smb_password}\ndomain=${var.ha_smb_domain}\nEOF",
      "sudo chmod 600 /root/.smb-ha",
      "grep -q '^//192\\.168\\.10\\.28/config /mnt/ha-config cifs' /etc/fstab || echo '//192.168.10.28/config /mnt/ha-config cifs vers=3.0,sec=ntlmssp,credentials=/root/.smb-ha,uid=100000,gid=100000,file_mode=0777,dir_mode=0777,noperm,_netdev 0 0' | sudo tee -a /etc/fstab > /dev/null",
      "mountpoint -q /mnt/ha-config || sudo mount /mnt/ha-config"
    ]
  }

  depends_on = [module.swarm_manager_vms, module.swarm_worker_vms]
}

# ==============================================================================
# NFS MOUNTS: PLEX MEDIA (AUTOMOUNT)
# ==============================================================================
resource "null_resource" "plex_media_mounts" {
  for_each = toset(local.all_node_ips)

  connection {
    type = "ssh"
    host = each.key
    user = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = concat(
      ["sudo mkdir -p /mnt/nfs/media-nas"],
      [for mount in local.plex_media_mounts : "sudo mkdir -p ${mount.dest}"],
      [for mount in local.plex_media_mounts : "grep -q '^${mount.src} ${mount.dest} nfs' /etc/fstab || echo '${mount.src} ${mount.dest} nfs defaults,nfsvers=3,rw,_netdev,nofail,x-systemd.automount,x-systemd.idle-timeout=600,x-systemd.device-timeout=30s 0 0' | sudo tee -a /etc/fstab > /dev/null"],
      [
        "sudo systemctl daemon-reload",
        "for mp in /mnt/nfs/media-nas/*; do mountpoint -q \"$mp\" || sudo mount \"$mp\" || true; done"
      ]
    )
  }

  depends_on = [module.swarm_manager_vms, module.swarm_worker_vms]
}

# ==============================================================================
# LXC CONTAINERS
# ==============================================================================
resource "proxmox_virtual_environment_download_file" "debian_lxc_template" {
  for_each = local.lxc_nodes

  node_name    = each.key
  datastore_id = var.lxc_template_storage
  content_type = "vztmpl"
  overwrite    = false

  url       = var.debian_lxc_template_url
  file_name = basename(var.debian_lxc_template_url)
}

module "lxc_containers" {
  for_each = var.lxc_containers
  source   = "./modules/proxmox-lxc"

  hostname = each.key
  vmid     = each.value.vmid
  node     = each.value.node
  ip       = each.value.ip

  cores   = each.value.cores
  memory  = each.value.memory
  disk_gb = each.value.disk_gb
  storage = coalesce(each.value.storage, var.default_vm_storage)

  os_template = proxmox_virtual_environment_download_file.debian_lxc_template[each.value.node].id

  lan_bridge  = var.lan_bridge
  lan_gateway = var.lan_gateway
  lan_dns     = var.lan_dns

  ssh_public_keys = var.ssh_public_keys
  tags            = concat(local.tags_common, ["lxc"])

  nfs_mounts  = each.value.nfs_mounts
  bind_mounts = each.value.bind_mounts
}

# ==============================================================================
# KEEPALIVED VIP ON MANAGERS
# ==============================================================================
resource "null_resource" "keepalived" {
  for_each = var.swarm_managers

  triggers = {
    config_hash = sha256(local.keepalived_config[each.key])
  }

  connection {
    type = "ssh"
    host = each.value.ip
    user = local.ssh_user
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y keepalived",
      "sudo mkdir -p /etc/keepalived",
      "cat <<'EOF' | sudo tee /etc/keepalived/keepalived.conf > /dev/null\n${local.keepalived_config[each.key]}\nEOF",
      "sudo systemctl enable --now keepalived"
    ]
  }

  depends_on = [module.swarm_manager_vms]
}
