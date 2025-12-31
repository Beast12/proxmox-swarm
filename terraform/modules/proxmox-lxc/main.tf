resource "proxmox_virtual_environment_container" "this" {
  node_name = var.node_name
  vm_id     = var.vmid
  description = var.name
  tags      = var.tags

  started       = true
  start_on_boot = true
  unprivileged  = true

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    size         = "${var.disk_gb}G"
  }

  initialization {
    hostname = var.name
    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }
}
