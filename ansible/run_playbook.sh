#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ansible_root="$repo_root/ansible"
playbook="${1:-playbooks/playbook.yml}"

if ! command -v bw >/dev/null 2>&1; then
  echo "bw CLI not found. Install with: npm install -g @bitwarden/cli" >&2
  exit 1
fi

if [[ -z "${BW_SESSION:-}" ]]; then
  echo "Unlocking Bitwarden..."
  BW_SESSION="$(bw unlock --raw)"
  export BW_SESSION
fi

export ANSIBLE_CONFIG="$ansible_root/ansible.cfg"
cd "$ansible_root"

shift || true
ansible-playbook "$playbook" "$@"
