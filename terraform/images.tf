resource "proxmox_virtual_environment_download_file" "debian_cloud" {
  for_each = toset(var.proxmox_nodes)

  node_name    = each.value
  datastore_id = var.cloud_image_datastore

  # Provider examples commonly use content_type = "iso" even for qcow2/img downloads.
  content_type = "iso"
  file_name    = var.debian_cloud_image_file_name
  url          = var.debian_cloud_image_url

  overwrite           = true
  overwrite_unmanaged = true
}
