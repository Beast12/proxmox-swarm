# Compose Migration (Dockhand + Git)

This directory contains non-Swarm Docker Compose variants of selected stacks.

## Included stacks

- `compose/dockhand`
- `compose/traefik`
- `compose/cloudflared`
- `compose/homepage`
- `compose/dev-tools`
- `compose/tools`

## Design goals

- Keep persistent bind mounts on `/mnt/proxmox_swarm_data/...` to preserve data.
- Remove Swarm-only settings (`deploy`, `placement`, `mode: global`, `traefik.swarm.network`).
- Make stacks deployable from Dockhand Git integration on remote hosts.

## Host prerequisites

- In your current setup, `proxy` is already provisioned by Terraform for swarm hosts.
- For any new non-Terraform host, create it once with:
  `docker network create proxy`

## Important for multi-host setups

Traefik Docker provider discovers containers on the same Docker host it is connected to.
If apps are spread across multiple hosts, either:

1. Run a Traefik instance per host, or
2. Keep one central Traefik and configure remote backends via file-provider config in `/mnt/proxmox_swarm_data/traefik/config`.

## Traefik auth file prerequisite

Create this file on the Traefik host:

`/mnt/proxmox_swarm_data/traefik/secrets/dashboard_users`

It should contain htpasswd-formatted users (one per line).
