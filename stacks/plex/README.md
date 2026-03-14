# Plex Migration

Plex has been removed from Docker Swarm stack definitions in this repository.

Use the dedicated Proxmox LXC container defined in Terraform:

- `terraform/terraform.tfvars` → `lxc_containers.plex`

To stop the old Swarm service if still running:

```bash
docker stack rm streaming
```

