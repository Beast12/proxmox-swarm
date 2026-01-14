#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Docker Swarm Infrastructure Setup            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Configuration
NFS_SERVER="192.168.10.10"
SWARM_DATA_ROOT="/mnt/proxmox_swarm_data"

# Directories to create
DIRECTORIES=(
    "${SWARM_DATA_ROOT}/dockge/data"
    "${SWARM_DATA_ROOT}/dockhand/data"
    "${SWARM_DATA_ROOT}/traefik/config"
    "${SWARM_DATA_ROOT}/authentik/media"
    "${SWARM_DATA_ROOT}/authentik/custom-templates"
    "${SWARM_DATA_ROOT}/authentik/certs"
    "${SWARM_DATA_ROOT}/monitoring/config"
    "${SWARM_DATA_ROOT}/monitoring/data/prometheus"
    "${SWARM_DATA_ROOT}/monitoring/data/grafana"
    "${SWARM_DATA_ROOT}/monitoring/data/loki"
    "${SWARM_DATA_ROOT}/monitoring/data/alertmanager"
    "${SWARM_DATA_ROOT}/tools/convertx"
    "${SWARM_DATA_ROOT}/tools/freshrss"
    "${SWARM_DATA_ROOT}/tools/stirling-pdf/data"
    "${SWARM_DATA_ROOT}/tools/stirling-pdf/config"
    "${SWARM_DATA_ROOT}/tools/stirling-pdf/logs"
    "${SWARM_DATA_ROOT}/tools/cronmaster/scripts"
    "${SWARM_DATA_ROOT}/tools/cronmaster/data"
    "${SWARM_DATA_ROOT}/tools/cronmaster/snippets"
    "${SWARM_DATA_ROOT}/tools/cronmaster/ssh"
    "${SWARM_DATA_ROOT}/development-tools/code-server/config"
    "${SWARM_DATA_ROOT}/development-tools/code-server/workspace"
    "${SWARM_DATA_ROOT}/development-tools/docker-registry/data"
    "${SWARM_DATA_ROOT}/services/redis/data"
    "${SWARM_DATA_ROOT}/stacks"
    "${SWARM_DATA_ROOT}/env-files"
    "/mnt/postgres-backups"
    "/mnt/postgres-config"
)

# NFS shares to mount
declare -A NFS_MOUNTS=(
    ["/volume1/proxmox_swarm_data"]="/mnt/proxmox_swarm_data"
    ["/volume1/postgresql_backups"]="/mnt/postgres-backups"
)

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

# Check if NFS server is reachable
echo -e "${YELLOW}→ Checking NFS server connectivity...${NC}"
if ! ping -c 1 -W 2 "$NFS_SERVER" &> /dev/null; then
    echo -e "${RED}✗ Cannot reach NFS server at $NFS_SERVER${NC}"
    exit 1
fi
echo -e "${GREEN}✓ NFS server is reachable${NC}\n"

# Install NFS client if needed
echo -e "${YELLOW}→ Checking NFS client packages...${NC}"
if ! command -v mount.nfs &> /dev/null; then
    echo -e "${YELLOW}  Installing nfs-common...${NC}"
    apt-get update -qq
    apt-get install -y nfs-common nfs4-acl-tools
fi
echo -e "${GREEN}✓ NFS client is installed${NC}\n"

# Create mount points and mount NFS shares
echo -e "${YELLOW}→ Mounting NFS shares...${NC}"
for remote in "${!NFS_MOUNTS[@]}"; do
    local="${NFS_MOUNTS[$remote]}"
    
    # Create mount point
    mkdir -p "$local"
    
    # Check if already mounted
    if mountpoint -q "$local"; then
        echo -e "${BLUE}  ℹ $local already mounted${NC}"
        continue
    fi
    
    # Add to fstab if not present
    if ! grep -q "$local" /etc/fstab; then
        echo "${NFS_SERVER}:${remote} ${local} nfs defaults,nfsvers=4,rw,sync,hard,intr 0 0" >> /etc/fstab
        echo -e "${GREEN}  ✓ Added $local to /etc/fstab${NC}"
    fi
    
    # Mount
    mount "$local"
    echo -e "${GREEN}  ✓ Mounted $local${NC}"
done
echo ""

# Create directory structure
echo -e "${YELLOW}→ Creating directory structure...${NC}"
for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo -e "${GREEN}  ✓ Created $dir${NC}"
    else
        echo -e "${BLUE}  ℹ $dir already exists${NC}"
    fi
done
echo ""

# Set base permissions
echo -e "${YELLOW}→ Setting permissions...${NC}"
chmod -R 775 "$SWARM_DATA_ROOT"

# Set specific permissions for data directories that need write access
chmod 777 "${SWARM_DATA_ROOT}/dockhand/data"
chmod 777 "${SWARM_DATA_ROOT}/dockge/data"
chmod 777 "${SWARM_DATA_ROOT}/monitoring/data/prometheus"
chmod 777 "${SWARM_DATA_ROOT}/monitoring/data/grafana"
chmod 777 "${SWARM_DATA_ROOT}/monitoring/data/loki"
chmod 777 "${SWARM_DATA_ROOT}/monitoring/data/alertmanager"
chmod 777 "${SWARM_DATA_ROOT}/authentik/media"
chmod 777 "${SWARM_DATA_ROOT}/authentik/custom-templates"
chmod 777 "${SWARM_DATA_ROOT}/authentik/certs"
chmod 777 "${SWARM_DATA_ROOT}/services/redis/data"
chmod 777 "${SWARM_DATA_ROOT}/development-tools"

echo -e "${GREEN}✓ Permissions configured${NC}\n"

# Create marker file
touch "${SWARM_DATA_ROOT}/.infrastructure-setup-complete"
date > "${SWARM_DATA_ROOT}/.infrastructure-setup-date"

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Infrastructure Setup Complete                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Set up PostgreSQL users: ${YELLOW}./scripts/setup-postgres-user.sh${NC}"
echo -e "  2. Create env files: ${YELLOW}./scripts/setup-env-file.sh <service>${NC}"
echo -e "  3. Deploy stacks: ${YELLOW}./scripts/deploy-stack.sh <stack>${NC}\n"

echo -e "${BLUE}Verify setup:${NC}"
echo -e "  mount | grep /mnt/proxmox_swarm_data"
echo -e "  ls -la $SWARM_DATA_ROOT"
echo ""
