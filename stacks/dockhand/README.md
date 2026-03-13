# Dockhand Stack

This stack deploys:
- `dockhand` (UI) on a swarm manager
- `hawser` in global mode (one agent per swarm node)

## Required env file

Create `/mnt/proxmox_swarm_data/env-files/dockhand.env`:

```bash
# Shared secret used by Hawser agents (recommended)
TOKEN=replace-with-a-long-random-token

# Optional Dockhand settings
# DATABASE_URL=postgres://user:password@postgresql_postgres:5432/dockhand
# ENCRYPTION_KEY=base64-32-byte-key
# PUID=1000
# PGID=1000
```

## Deploy

```bash
docker stack deploy -c stacks/dockhand/docker-compose.yaml dockhand
```

## Remote node connections in Dockhand

After deploy, add environments in Dockhand with connection type `Hawser Standard`:
- `swarm-manager-m1:2376`
- `swarm-manager-m2:2376`
- `swarm-manager-m3:2376`
- `swarm-worker-w1:2376`
- `swarm-worker-w2:2376`

Use the same token value as `TOKEN` in `dockhand.env`.
