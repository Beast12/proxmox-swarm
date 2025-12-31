locals {
  env      = terraform.workspace
  name_pfx = "pve-${local.env}"

  tags_common = [
    "managed-by-terraform",
    "env-${local.env}",
  ]
}
