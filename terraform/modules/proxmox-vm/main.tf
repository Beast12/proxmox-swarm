locals {
  user_data_name    = "${var.name}-user-data.yaml"
  network_data_name = "${var.name}-network-data.yaml"

  ssh_keys_joined = join("\n", var.ssh_public_keys)
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
      ssh_public_keys = local.ssh_keys_joined
      dns_servers     = local.dns_joined
      password_hash   = var.password_hash
    })
  }
}

resource "proxmox_virtual_environment_file" "network_data" {
  node_name    = var.node_name
  datastore_id = var.snippet_ds
  content_type = "snippets"

  source_raw {
    file_name = local.network_data_name
    data = templatefile("${path.module}/cloud-init/network-data.yaml.tmpl", {
      ip      = var.ip
      gateway = var.gateway
      dns     = var.dns
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

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = var.disk_gb
    file_id      = var.cloud_image_file_id
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
    user_data_file_id    = proxmox_virtual_environment_file.user_data.id
    network_data_file_id = proxmox_virtual_environment_file.network_data.id
  }
}
