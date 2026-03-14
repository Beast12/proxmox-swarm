# Plex Ansible Role

Installs Plex Media Server as a native package (`plexmediaserver`) on the Plex LXC.

The role installs from Plex's official download API (`https://plex.tv/api/downloads/5.json`) and
installs the `.deb` directly, avoiding apt repository signature issues.

## Files

- `ansible/roles/plex/*` — reusable role
- `ansible/plex/playbook.yml` — playbook using the role
- `ansible/plex/inventory.yml` — inventory targeting Plex LXC (`192.168.10.107`)

## Run

```bash
ansible-playbook -i ansible/plex/inventory.yml ansible/plex/playbook.yml
```

## Proxmox Host Bind Mount Strategy (recommended when LXC NFS is blocked)

This repo includes a dedicated playbook that:

1. mounts NAS shares on the Proxmox host
2. applies `pct set -mpX` bind mounts into Plex LXC

Run:

```bash
ansible-playbook -i ansible/plex/proxmox-bind-inventory.yml ansible/plex/proxmox-bind-playbook.yml
```

## Defaults

Important role defaults are in:

`ansible/roles/plex/defaults/main.yml`

Notable variables:

- `plex_data_dir` (default `/mnt/proxmox_swarm_data/plex`)
- `plex_enable_hw_transcode` (default `false`)
- `plex_deb_url_override` (optional pin to a specific `.deb` URL)

If you pass through GPU to the LXC later, set:

```bash
ansible-playbook -i ansible/plex/inventory.yml ansible/plex/playbook.yml \
  -e "plex_enable_hw_transcode=true"
```
