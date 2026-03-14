# Jellyfin Ansible Role

Installs Jellyfin as a native package on the same LXC host used for Plex (default: `192.168.10.107`).

## Files

- `ansible/roles/jellyfin/*` — reusable role
- `ansible/jellyfin/playbook.yml` — playbook
- `ansible/jellyfin/inventory.yml` — inventory

## Run

```bash
ansible-playbook -i ansible/jellyfin/inventory.yml ansible/jellyfin/playbook.yml
```

## Hardware Transcoding

Enable GPU groups:

```bash
ansible-playbook -i ansible/jellyfin/inventory.yml ansible/jellyfin/playbook.yml \
  -e "jellyfin_enable_hw_transcode=true"
```

