#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
TF_DIR="${REPO_ROOT}/terraform"

# 1) Remove env wrappers
if [ -d "${TF_DIR}/envs" ]; then
  echo "Removing ${TF_DIR}/envs ..."
  rm -rf "${TF_DIR}/envs"
fi

# 2) Ensure module skeleton exists (in case it was never created)
mkdir -p "${TF_DIR}/modules/proxmox-vm/cloud-init"
mkdir -p "${TF_DIR}/modules/proxmox-lxc"

for f in \
  "${TF_DIR}/modules/proxmox-vm/main.tf" \
  "${TF_DIR}/modules/proxmox-vm/variables.tf" \
  "${TF_DIR}/modules/proxmox-vm/outputs.tf" \
  "${TF_DIR}/modules/proxmox-vm/cloud-init/user-data.yaml.tmpl" \
  "${TF_DIR}/modules/proxmox-vm/cloud-init/network-data.yaml.tmpl" \
  "${TF_DIR}/modules/proxmox-lxc/main.tf" \
  "${TF_DIR}/modules/proxmox-lxc/variables.tf" \
  "${TF_DIR}/modules/proxmox-lxc/outputs.tf"
do
  [ -f "$f" ] || touch "$f"
done

# 3) Create root tfvars if missing
[ -f "${TF_DIR}/terraform.tfvars" ] || touch "${TF_DIR}/terraform.tfvars"

echo "Done."
echo "Next: run 'tree -L 3 terraform' and ensure terraform/envs is gone."

