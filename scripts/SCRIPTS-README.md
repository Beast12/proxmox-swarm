# Docker Swarm Infrastructure Scripts

Simple bash scripts to replace Ansible for Docker Swarm infrastructure management.

## Quick Start

```bash
# 1. Make all scripts executable
chmod +x scripts/*.sh

# 2. Run complete setup (interactive)
sudo ./scripts/setup-all.sh

# Or manually step by step:

# 3. Set up infrastructure
sudo ./scripts/setup-infrastructure.sh

# 4. Create networks
sudo ./scripts/setup-networks.sh

# 5. Set up database users
./scripts/setup-postgres-user.sh dockhand dockhand
./scripts/setup-postgres-user.sh authentik authentik

# 6. Create environment files
./scripts/setup-env-file.sh dockhand
./scripts/setup-env-file.sh traefik

# 7. Deploy stacks
./scripts/deploy-stack.sh dockhand
./scripts/deploy-stack.sh traefik
```

## Scripts Overview

### `setup-all.sh` (Master Script)
Orchestrates the entire setup process interactively.
```bash
sudo ./scripts/setup-all.sh
```

### `setup-infrastructure.sh`
- Mounts NFS shares
- Creates directory structure
- Sets permissions
```bash
sudo ./scripts/setup-infrastructure.sh
```

### `setup-networks.sh`
Creates Docker overlay networks for Swarm.
```bash
./scripts/setup-networks.sh
```

### `setup-postgres-user.sh`
Creates PostgreSQL users and databases.
```bash
# Syntax: ./scripts/setup-postgres-user.sh <username> <database> [password]

# Auto-generate password
./scripts/setup-postgres-user.sh dockhand dockhand

# Specify password
./scripts/setup-postgres-user.sh authentik authentik 'MySecurePass123!'
```

### `setup-env-file.sh`
Creates environment files with interactive prompts.
```bash
# Syntax: ./scripts/setup-env-file.sh <service>

# Supported services: dockhand, dockge, traefik, authentik, redis
./scripts/setup-env-file.sh dockhand
./scripts/setup-env-file.sh traefik
```

### `deploy-stack.sh`
Manages Docker stack deployments.
```bash
# Deploy or update
./scripts/deploy-stack.sh dockhand deploy

# View logs
./scripts/deploy-stack.sh dockhand logs

# Check status
./scripts/deploy-stack.sh dockhand ps

# Restart services
./scripts/deploy-stack.sh dockhand restart

# Remove stack
./scripts/deploy-stack.sh dockhand remove
```

## Directory Structure

```
/mnt/proxmox_swarm_data/
├── env-files/           # Environment files
│   ├── dockhand.env
│   ├── traefik.env
│   └── ...
├── dockhand/
│   └── data/
├── dockge/
│   └── data/
├── traefik/
│   └── config/
└── stacks/              # For Dockge managed stacks
```

## Comparison: Ansible vs Bash Scripts

### Ansible Approach
```bash
cd ansible
export BW_SESSION=$(bw unlock --raw)
ansible-playbook playbooks/playbook.yml
```

**Pros:**
- Idempotent
- Bitwarden integration
- Inventory management
- Role reusability

**Cons:**
- Requires Python, pip, Ansible
- Requires Bitwarden CLI
- More complex
- Harder to debug
- Slower execution

### Bash Scripts Approach
```bash
sudo ./scripts/setup-all.sh
```

**Pros:**
- No dependencies (just bash, docker, openssl)
- Direct and transparent
- Easy to understand
- Fast execution
- Easy to debug
- No Bitwarden required

**Cons:**
- Not idempotent (can handle this with checks)
- Manual secret management
- Less abstraction

## Common Tasks

### Deploy Dockhand
```bash
./scripts/setup-postgres-user.sh dockhand dockhand
./scripts/setup-env-file.sh dockhand
./scripts/deploy-stack.sh dockhand
```

### Deploy Traefik
```bash
./scripts/setup-env-file.sh traefik
./scripts/deploy-stack.sh traefik
```

### View Service Logs
```bash
./scripts/deploy-stack.sh dockhand logs

# Or directly
docker service logs -f dockhand_dockhand
```

### Update a Stack
```bash
# Just redeploy
./scripts/deploy-stack.sh dockhand deploy

# Or force update all services
./scripts/deploy-stack.sh dockhand restart
```

### Check Status
```bash
docker service ls
docker stack ls
docker stack ps dockhand
./scripts/deploy-stack.sh dockhand ps
```

### Remove a Stack
```bash
./scripts/deploy-stack.sh dockhand remove
```

## Environment File Locations

All environment files are stored in:
```
/mnt/proxmox_swarm_data/env-files/
```

Permissions: `600` (owner read/write only)

## PostgreSQL Management

### List Users
```bash
docker exec -it $(docker ps -q -f "name=postgresql_postgres") \
  psql -U postgres -c "\du"
```

### List Databases
```bash
docker exec -it $(docker ps -q -f "name=postgresql_postgres") \
  psql -U postgres -c "\l"
```

### Connect to Database
```bash
docker exec -it $(docker ps -q -f "name=postgresql_postgres") \
  psql -U dockhand -d dockhand
```

## Troubleshooting

### NFS Mount Issues
```bash
# Check mounts
mount | grep /mnt/proxmox_swarm_data

# Remount
sudo umount /mnt/proxmox_swarm_data
sudo mount /mnt/proxmox_swarm_data
```

### Network Issues
```bash
# List networks
docker network ls

# Recreate network
docker network rm traefik_public
./scripts/setup-networks.sh
```

### PostgreSQL Connection Issues
```bash
# Check if container is running
docker ps | grep postgres

# Check logs
docker service logs postgresql_postgres

# Test connection
./scripts/setup-postgres-user.sh testuser testdb
```

### Permission Issues
```bash
# Fix data directory permissions
sudo chmod 777 /mnt/proxmox_swarm_data/dockhand/data
sudo chmod 777 /mnt/proxmox_swarm_data/dockge/data
```

## Security Notes

1. **Environment files** contain sensitive data - permissions set to `600`
2. **PostgreSQL passwords** are shown once during setup - save them securely
3. **Session secrets** are auto-generated using `openssl rand`
4. **NFS security** - ensure proper network isolation
5. **Docker socket** - mounted read-only for management tools

## Migration from Ansible

If you're currently using Ansible:

1. Note your current configuration from inventory files
2. Run the bash scripts to create the same setup
3. Deploy stacks using the new scripts
4. Verify everything works
5. Keep Ansible files as backup/reference

The bash scripts create the exact same infrastructure as Ansible, just with a simpler approach.
