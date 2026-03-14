# Plex Migration

Plex has been removed from Docker Swarm stack definitions in this repository.

Use the dedicated Proxmox LXC container defined in Terraform:

- `terraform/terraform.tfvars` → `lxc_containers.plex`

The Plex LXC now uses **bind mounts** from the Proxmox host, not in-container NFS mounts.
Ensure these paths are mounted on the Proxmox host (`proxmox-1`) before applying:

- `/mnt/proxmox_swarm_data/plex`
- `/mnt/nfs/media-nas/movies`
- `/mnt/nfs/media-nas/tv`
- `/mnt/nfs/media-nas/music`
- `/mnt/nfs/media-nas/cartoons`
- `/mnt/nfs/media-nas/comedy`
- `/mnt/nfs/media-nas/audiobooks`
- `/mnt/nfs/media-nas/comics`

To stop the old Swarm service if still running:

```bash
docker stack rm streaming
```
