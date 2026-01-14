#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 <stack-name> [action]"
    echo ""
    echo -e "${BLUE}Actions:${NC}"
    echo "  deploy   - Deploy or update the stack (default)"
    echo "  remove   - Remove the stack"
    echo "  restart  - Restart all services in the stack"
    echo "  logs     - Follow logs for the stack"
    echo "  ps       - Show stack services status"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    echo "  $0 dockhand deploy"
    echo "  $0 dockhand logs"
    echo "  $0 dockhand remove"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

STACK_NAME="$1"
ACTION="${2:-deploy}"
STACK_DIR="stacks/${STACK_NAME}"

# Check if stack directory exists
if [ ! -d "$STACK_DIR" ]; then
    echo -e "${RED}✗ Stack directory not found: $STACK_DIR${NC}"
    echo ""
    echo -e "${YELLOW}Available stacks:${NC}"
    ls -d stacks/*/ 2>/dev/null | xargs -n1 basename || echo "  No stacks found in stacks/ directory"
    exit 1
fi

# Check if docker-compose.yaml exists
if [ ! -f "$STACK_DIR/docker-compose.yaml" ]; then
    echo -e "${RED}✗ docker-compose.yaml not found in $STACK_DIR${NC}"
    exit 1
fi

case "$ACTION" in
    deploy)
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  Deploying Stack: ${STACK_NAME}                      ${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${YELLOW}→ Deploying from: $STACK_DIR${NC}"
        
        cd "$STACK_DIR"
        docker stack deploy -c docker-compose.yaml "$STACK_NAME"
        
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  Stack Deployed Successfully                   ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${BLUE}Monitor deployment:${NC}"
        echo -e "  docker service ls | grep $STACK_NAME"
        echo -e "  docker stack ps $STACK_NAME"
        echo ""
        echo -e "${BLUE}View logs:${NC}"
        echo -e "  docker service logs -f ${STACK_NAME}_${STACK_NAME}"
        echo ""
        ;;
        
    remove)
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  Removing Stack: ${STACK_NAME}                       ${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${YELLOW}⚠ This will remove all services in the stack${NC}"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Aborted.${NC}"
            exit 0
        fi
        
        docker stack rm "$STACK_NAME"
        
        echo ""
        echo -e "${GREEN}✓ Stack removed${NC}\n"
        ;;
        
    restart)
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  Restarting Stack: ${STACK_NAME}                     ${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${YELLOW}→ Getting services...${NC}"
        SERVICES=$(docker stack services "$STACK_NAME" --format "{{.Name}}" 2>/dev/null)
        
        if [ -z "$SERVICES" ]; then
            echo -e "${RED}✗ No services found for stack: $STACK_NAME${NC}"
            exit 1
        fi
        
        for service in $SERVICES; do
            echo -e "${YELLOW}→ Restarting $service...${NC}"
            docker service update --force "$service" > /dev/null 2>&1
            echo -e "${GREEN}✓ Restarted $service${NC}"
        done
        
        echo ""
        echo -e "${GREEN}✓ All services restarted${NC}\n"
        ;;
        
    logs)
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  Logs: ${STACK_NAME}                                 ${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
        
        # Try to find the main service (usually same name as stack)
        if docker service ls --format "{{.Name}}" | grep -q "^${STACK_NAME}_${STACK_NAME}$"; then
            docker service logs -f "${STACK_NAME}_${STACK_NAME}"
        else
            # List all services and let user choose
            echo -e "${YELLOW}Available services:${NC}"
            docker stack services "$STACK_NAME" --format "  {{.Name}}"
            echo ""
            echo -e "${BLUE}View logs for a specific service:${NC}"
            echo -e "  docker service logs -f ${STACK_NAME}_<service>"
        fi
        ;;
        
    ps)
        echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║  Stack Status: ${STACK_NAME}                         ${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"
        
        docker stack ps "$STACK_NAME"
        echo ""
        echo -e "${BLUE}Services:${NC}"
        docker stack services "$STACK_NAME"
        echo ""
        ;;
        
    *)
        echo -e "${RED}✗ Unknown action: $ACTION${NC}"
        usage
        ;;
esac
