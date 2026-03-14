# Plex Ansible Role

Installs Docker + Docker Compose plugin on the Plex LXC and deploys Plex using a compose file.

## Files

- `ansible/roles/plex/*` — reusable role
- `ansible/plex/playbook.yml` — playbook using the role
- `ansible/plex/inventory.yml` — inventory targeting Plex LXC (`192.168.10.107`)

## Run

```bash
ansible-playbook -i ansible/plex/inventory.yml ansible/plex/playbook.yml
```

## Defaults

Important role defaults are in:

`ansible/roles/plex/defaults/main.yml`

Notable variables:

- `plex_enable_hw_transcode` (default `false`)
- `plex_config_dir` (default `/mnt/proxmox_swarm_data/plex/config`)
- `plex_env_file` (default `/mnt/proxmox_swarm_data/env-files/plex.env`)

If you pass through GPU to the LXC later, set:

```bash
ansible-playbook -i ansible/plex/inventory.yml ansible/plex/playbook.yml \
  -e "plex_enable_hw_transcode=true"
```

