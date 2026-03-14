# Dockhand (Compose)

This stack deploys Dockhand only. Hawser should run as a host-level service on remote Docker hosts.

## Required env file

Create `/mnt/proxmox_swarm_data/env-files/dockhand.env`:

```bash
# Optional settings
# DATABASE_URL=postgres://user:password@postgres-host:5432/dockhand
# ENCRYPTION_KEY=<base64-32-byte-key>
# PUID=1000
# PGID=1000
```

## Deploy

Use this compose file in Dockhand Git integration:

`compose/dockhand/docker-compose.yaml`

## Hawser for remote hosts

Use systemd install per host (see `compose/hawser/README.md`), then add environments in Dockhand:

- `Hawser Standard`: `http://<host>:2376` + token
- `Hawser Edge`: token only (host dials out to Dockhand)

