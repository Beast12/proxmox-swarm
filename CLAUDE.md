# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure-as-code for a Proxmox-based Docker Swarm homelab. Three layers:

1. **Terraform (OpenTofu)** — provisions Proxmox VMs/LXCs and creates Docker overlay networks
2. **Ansible** — OS-level config (rolling dist-upgrades, Grafana Alloy for Proxmox monitoring)
3. **Docker Swarm stacks** — application workloads in `stacks/<name>/docker-compose.yaml`

## Common commands

### Docker Swarm
```bash
# Deploy or update a single stack (run on a swarm manager)
docker stack deploy -c stacks/<name>/docker-compose.yaml <name>

# Redeploy all currently running stacks
./scripts/update-stacks.sh

# View running stacks / services
docker stack ls
docker stack services <name>
```

### Terraform (OpenTofu)
```bash
cd terraform
tofu init
tofu workspace select <env>   # env separation via workspaces
tofu plan
tofu apply
```

### Ansible
```bash
# Rolling dist-upgrade of all swarm nodes (drains each node before upgrading)
ansible-playbook -i ansible/swarm-nodes/inventory.yml ansible/swarm-nodes/dist-upgrade.yml

# Deploy Grafana Alloy to Proxmox hosts
ansible-playbook -i ansible/alloy-proxmox/inventory.yml ansible/alloy-proxmox/playbook.yml
```

## Architecture

### Terraform modules
- `terraform/modules/proxmox-vm` — creates Ubuntu 24.04 VMs with cloud-init
- `terraform/modules/proxmox-lxc` — creates Debian LXC containers
- `terraform/docker.tf` — creates external Docker overlay networks used by all stacks
- `terraform/main.tf` — managers, workers, NFS/CIFS mounts, keepalived VIP, LXC containers

Workers with `gpu_passthrough = true` use machine type `q35`; managers always use `pc`.

Keepalived is configured via `terraform/templates/keepalived.conf.tmpl` and installed via `null_resource` remote-exec, providing a VIP across manager nodes.

### Docker stack conventions
- All overlay networks are **external** — created by Terraform, not by stacks
- Env files live on NFS at `/mnt/proxmox_swarm_data/env-files/<name>.env` (not in this repo)
- Persistent data lives under `/mnt/proxmox_swarm_data/<service>/`
- Every service must have `deploy.resources` with both `limits` and `reservations`
- Traefik routing is configured entirely via `deploy.labels` on each service
- Homepage dashboard entries are also configured via `deploy.labels` (e.g. `homepage.group`, `homepage.name`, `homepage.href`)

### Key overlay networks (all external)
| Network | Purpose |
|---------|---------|
| `proxy` | Traefik reverse proxy |
| `postgres_network` | DB connectivity to shared Postgres |
| `monitoring` | Prometheus/Grafana scraping |
| `services` | Misc inter-service communication |
| `cronjob_net` | Swarm cronjob scheduler |

### Traefik label pattern
```yaml
deploy:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.<name>.rule=Host(`<name>.tuxito.be`)"
    - "traefik.http.routers.<name>.entrypoints=websecure"
    - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
    - "traefik.http.services.<name>.loadbalancer.server.port=<port>"
    - "traefik.swarm.network=proxy"
```

TCP services (e.g. Postgres) use `traefik.tcp.routers` instead.

### NFS storage layout
- `/mnt/proxmox_swarm_data/` — shared config and data (NAS at 192.168.10.10)
- `/mnt/postgres-backups/` — Postgres backup target (NAS at 192.168.10.10)
- `/mnt/nfs/media-nas/` — Plex media library (NAS at 192.168.10.9)
- `/mnt/ha-config/` — Home Assistant config (CIFS from 192.168.10.28)
