#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Docker Swarm Infrastructure - Complete Setup               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}✗ Please run as root or with sudo${NC}"
    exit 1
fi

# Check if Docker Swarm is initialized
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${RED}✗ Docker Swarm is not initialized${NC}"
    echo -e "${YELLOW}Initialize with: docker swarm init${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Swarm is active${NC}\n"

# Make all scripts executable
echo -e "${YELLOW}→ Making scripts executable...${NC}"
chmod +x "$SCRIPTS_DIR"/*.sh
echo -e "${GREEN}✓ Scripts are executable${NC}\n"

# Step 1: Infrastructure
echo -e "${CYAN}═══ Step 1: Infrastructure Setup ═══${NC}\n"
if [ -f "${SCRIPTS_DIR}/setup-infrastructure.sh" ]; then
    bash "${SCRIPTS_DIR}/setup-infrastructure.sh"
else
    echo -e "${RED}✗ setup-infrastructure.sh not found${NC}"
    exit 1
fi

# Step 2: Networks
echo -e "\n${CYAN}═══ Step 2: Docker Networks ═══${NC}\n"
if [ -f "${SCRIPTS_DIR}/setup-networks.sh" ]; then
    bash "${SCRIPTS_DIR}/setup-networks.sh"
else
    echo -e "${RED}✗ setup-networks.sh not found${NC}"
    exit 1
fi

# Step 3: Interactive setup
echo -e "\n${CYAN}═══ Step 3: Service Configuration ═══${NC}\n"

echo -e "${BLUE}Would you like to set up PostgreSQL users now?${NC}"
echo -e "${YELLOW}Services that need PostgreSQL:${NC}"
echo "  - dockhand"
echo "  - authentik"
echo "  - nextcloud"
echo "  - (and others...)"
echo ""
read -p "Set up PostgreSQL users? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Example: ./scripts/setup-postgres-user.sh dockhand dockhand${NC}"
    echo ""
    echo -e "${BLUE}Set up Dockhand user? (y/N):${NC} "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "${SCRIPTS_DIR}/setup-postgres-user.sh" dockhand dockhand
    fi
fi

echo ""
echo -e "${BLUE}Would you like to create environment files now?${NC}"
read -p "Create environment files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Available services: dockhand, dockge, traefik, authentik, redis${NC}"
    echo ""
    echo -e "${BLUE}Create Dockhand env file? (y/N):${NC} "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash "${SCRIPTS_DIR}/setup-env-file.sh" dockhand
    fi
fi

# Summary
echo ""
echo -e "${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   Setup Complete!                                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${GREEN}✓ Infrastructure configured${NC}"
echo -e "${GREEN}✓ Networks created${NC}"
echo ""

echo -e "${BLUE}Next Steps:${NC}\n"

echo -e "${YELLOW}1. Set up additional PostgreSQL users:${NC}"
echo -e "   ./scripts/setup-postgres-user.sh <username> <database>"
echo ""

echo -e "${YELLOW}2. Create environment files:${NC}"
echo -e "   ./scripts/setup-env-file.sh <service>"
echo ""

echo -e "${YELLOW}3. Deploy stacks:${NC}"
echo -e "   ./scripts/deploy-stack.sh <stack-name>"
echo ""

echo -e "${BLUE}Quick Start Examples:${NC}\n"

echo -e "${CYAN}Deploy Dockhand:${NC}"
echo -e "  ./scripts/setup-postgres-user.sh dockhand dockhand"
echo -e "  ./scripts/setup-env-file.sh dockhand"
echo -e "  ./scripts/deploy-stack.sh dockhand"
echo ""

echo -e "${CYAN}Deploy Traefik:${NC}"
echo -e "  ./scripts/setup-env-file.sh traefik"
echo -e "  ./scripts/deploy-stack.sh traefik"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo -e "  docker service ls              # List all services"
echo -e "  docker stack ls                # List all stacks"
echo -e "  docker network ls              # List all networks"
echo -e "  ./scripts/deploy-stack.sh <stack> logs    # View logs"
echo -e "  ./scripts/deploy-stack.sh <stack> ps      # Check status"
echo ""

echo -e "${GREEN}Happy deploying! 🚀${NC}\n"
