resource "proxmox_virtual_environment_container" "this" {
  description  = "Managed by Terraform"
  node_name    = var.node
  vm_id        = var.vmid
  tags         = var.tags
  unprivileged = false
  started      = true

  operating_system {
    template_file_id = var.os_template
    type             = "debian"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.lan_bridge
  }

  initialization {
    hostname = var.hostname

    dns {
      servers = var.lan_dns
    }

    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.lan_gateway
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  dynamic "mount_point" {
    for_each = var.bind_mounts
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      read_only = mount_point.value.read_only
      shared    = mount_point.value.shared
    }
  }

}

# ==============================================================================
# NFS MOUNTS
# Installs nfs-common, writes fstab entries, and mounts all shares in one
# SSH session. Add entries to nfs_mounts in your tfvars to attach NFS shares.
# ==============================================================================
resource "null_resource" "nfs_mounts" {
  count = length(var.nfs_mounts) > 0 ? 1 : 0

  depends_on = [proxmox_virtual_environment_container.this]

  connection {
    type = "ssh"
    host = var.ip
    user = "root"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "apt-get update -y",
        "apt-get install -y nfs-common",
      ],
      [for m in var.nfs_mounts : "mkdir -p ${m.mount}"],
      [for m in var.nfs_mounts : "grep -q '^${m.server}:${m.export} ${m.mount} nfs' /etc/fstab || echo '${m.server}:${m.export} ${m.mount} nfs ${m.options} 0 0' >> /etc/fstab"],
      [for m in var.nfs_mounts : "mountpoint -q ${m.mount} || mount ${m.mount} || true"],
    )
  }
}
