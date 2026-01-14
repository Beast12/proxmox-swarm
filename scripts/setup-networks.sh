#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Docker Swarm Network Setup                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Networks to create
declare -A NETWORKS=(
    [traefik_public]="overlay,encrypted=true"
    [monitoring]="overlay,encrypted=false"
    [services]="overlay,encrypted=false"
    [postgres_network]="overlay,encrypted=true"
)

create_network() {
    local name=$1
    local config=$2
    local driver=$(echo "$config" | cut -d',' -f1)
    local encrypted=$(echo "$config" | cut -d'=' -f2)
    
    if docker network ls --format "{{.Name}}" | grep -q "^${name}$"; then
        echo -e "${BLUE}  ℹ Network '$name' already exists${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}→ Creating network '$name'...${NC}"
    
    local cmd="docker network create --driver $driver --scope swarm --attachable"
    
    if [ "$encrypted" = "true" ]; then
        cmd="$cmd --opt encrypted=true"
    fi
    
    cmd="$cmd $name"
    
    if eval "$cmd" > /dev/null; then
        echo -e "${GREEN}✓ Created network '$name'${NC}"
    else
        echo -e "${RED}✗ Failed to create network '$name'${NC}"
        return 1
    fi
}

# Create networks
for network in "${!NETWORKS[@]}"; do
    create_network "$network" "${NETWORKS[$network]}"
done

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Network Setup Complete                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Available networks:${NC}"
docker network ls --filter "driver=overlay" --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
echo ""

echo -e "${BLUE}Verify network configuration:${NC}"
echo -e "  docker network inspect <network-name>"
echo ""
