# Streaming Stack Migration

Plex has been migrated out of Docker Swarm due to stability issues in this setup.

Use the dedicated Proxmox LXC (`lxc_containers.plex`) managed via Terraform instead.

If the old Swarm stack is still running, remove it on a manager:

```bash
docker stack rm streaming
```

