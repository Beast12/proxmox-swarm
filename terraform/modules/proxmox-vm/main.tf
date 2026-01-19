locals {
  user_data_name    = "${var.name}-user-data.yaml"

  dns_joined      = join(" ", var.dns)
}

# ==============================================================================
# CLOUD-INIT FILES
# ==============================================================================
resource "proxmox_virtual_environment_file" "user_data" {
  node_name    = var.node_name
  datastore_id = var.snippet_ds
  content_type = "snippets"

  source_raw {
    file_name = local.user_data_name
    data = templatefile("${path.module}/cloud-init/user-data.yaml.tmpl", {
      hostname        = var.name
      ssh_public_keys = var.ssh_public_keys
      dns_servers     = local.dns_joined
      password_hash   = var.password_hash
    })
  }
}

# ==============================================================================
# VM RESOURCE
# ==============================================================================
resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vmid
  tags      = var.tags

  # Q35 machine type required for PCIe passthrough
  machine = var.machine_type

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  serial_device {
    device = "socket"
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    import_from  = var.cloud_image_import_id
    size         = var.disk_gb
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  # Intel Arc GPU Passthrough (00:02.0)
  dynamic "hostpci" {
    for_each = var.gpu_passthrough ? [1] : []
    content {
      device  = "hostpci0"
      mapping = "intel-arc"
      pcie    = true
      rombar  = false
    }
  }
  initialization {
    ip_config {
      ipv4 {
        address = "${var.ip}/24"
        gateway = var.gateway
      }
    }
    dns {
      servers = var.dns
    }
    user_data_file_id    = proxmox_virtual_environment_file.user_data.id
  }
}
