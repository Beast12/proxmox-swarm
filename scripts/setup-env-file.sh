#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENV_DIR="/mnt/proxmox_swarm_data/env-files"

# Usage
usage() {
    echo -e "${BLUE}Usage:${NC} $0 <service>"
    echo ""
    echo -e "${BLUE}Supported services:${NC}"
    echo "  - dockhand"
    echo "  - dockge"
    echo "  - traefik"
    echo "  - authentik"
    echo "  - redis"
    echo ""
    echo -e "${BLUE}Example:${NC}"
    echo "  $0 dockhand"
    exit 1
}

if [ $# -ne 1 ]; then
    usage
fi

SERVICE="$1"
ENV_FILE="${ENV_DIR}/${SERVICE}.env"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Environment File Setup                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Create env-files directory if it doesn't exist
mkdir -p "$ENV_DIR"

# Check if file already exists
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}⚠ File already exists: $ENV_FILE${NC}"
    read -p "  Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Aborted.${NC}"
        exit 0
    fi
fi

case "$SERVICE" in
    dockhand)
        echo -e "${YELLOW}→ Creating Dockhand environment file...${NC}"
        read -p "Database password: " -s DB_PASSWORD
        echo
        SESSION_SECRET=$(openssl rand -hex 32)
        
        cat > "$ENV_FILE" <<-EOF
# Dockhand Configuration
# https://dockhand.pro

# Database Configuration
DATABASE_URL=postgresql://dockhand:${DB_PASSWORD}@postgres:5432/dockhand

# Session Secret
SESSION_SECRET=${SESSION_SECRET}

# Application Configuration
TZ=Europe/Brussels
PORT=5173

# Optional: OIDC/SSO Configuration (uncomment to enable)
# OIDC_ISSUER=https://sso.tuxito.be/application/o/dockhand/
# OIDC_CLIENT_ID=your_client_id
# OIDC_CLIENT_SECRET=your_client_secret
# OIDC_CALLBACK_URL=https://dockhand.tuxito.be/auth/callback

# Optional: SMTP Configuration (uncomment to enable)
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USER=notifications@example.com
# SMTP_PASSWORD=your_smtp_password
# SMTP_FROM=Dockhand <notifications@example.com>
EOF
        ;;
        
    dockge)
        echo -e "${YELLOW}→ Creating Dockge environment file...${NC}"
        
        cat > "$ENV_FILE" <<-EOF
# Dockge Configuration
# https://github.com/louislam/dockge

# Stacks directory
DOCKGE_STACKS_DIR=/opt/stacks

# Application Configuration
DOCKGE_PORT=5001
TZ=Europe/Brussels
EOF
        ;;
        
    traefik)
        echo -e "${YELLOW}→ Creating Traefik environment file...${NC}"
        read -p "Cloudflare API Token: " -s CF_TOKEN
        echo
        read -p "Cloudflare Email: " CF_EMAIL
        read -p "ACME Email: " ACME_EMAIL
        
        cat > "$ENV_FILE" <<-EOF
# Traefik Configuration

# Cloudflare DNS Challenge
CLOUDFLARE_DNS_API_TOKEN=${CF_TOKEN}
CF_API_EMAIL=${CF_EMAIL}

# Let's Encrypt
ACME_EMAIL=${ACME_EMAIL}

# Traefik Configuration
LOG_LEVEL=INFO
TRAEFIK_REPLICAS=2
TRAEFIK_DOMAIN=traefik.tuxito.be
DOMAIN=tuxito.be
EOF
        ;;
        
    authentik)
        echo -e "${YELLOW}→ Creating Authentik environment file...${NC}"
        read -p "PostgreSQL password: " -s PG_PASSWORD
        echo
        read -p "Redis password: " -s REDIS_PASSWORD
        echo
        SECRET_KEY=$(openssl rand -hex 32)
        
        cat > "$ENV_FILE" <<-EOF
# Authentik Configuration

# PostgreSQL
AUTHENTIK_POSTGRESQL__HOST=postgres
AUTHENTIK_POSTGRESQL__PORT=5432
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=${PG_PASSWORD}

# Redis
AUTHENTIK_REDIS__HOST=redis
AUTHENTIK_REDIS__PORT=6379
AUTHENTIK_REDIS__DB=5
AUTHENTIK_REDIS__PASSWORD=${REDIS_PASSWORD}

# Authentik
AUTHENTIK_SECRET_KEY=${SECRET_KEY}
EOF
        ;;
        
    redis)
        echo -e "${YELLOW}→ Creating Redis environment file...${NC}"
        REDIS_PASSWORD=$(openssl rand -base64 32)
        
        cat > "$ENV_FILE" <<-EOF
# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}
EOF
        
        echo -e "${BLUE}Generated Redis password: ${YELLOW}${REDIS_PASSWORD}${NC}"
        ;;
        
    *)
        echo -e "${RED}✗ Unknown service: $SERVICE${NC}"
        usage
        ;;
esac

# Set restrictive permissions
chmod 600 "$ENV_FILE"

echo -e "${GREEN}✓ Created $ENV_FILE${NC}\n"

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Environment File Created                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}File location:${NC} ${YELLOW}$ENV_FILE${NC}"
echo -e "${BLUE}Permissions:${NC}   ${YELLOW}$(stat -c '%a' "$ENV_FILE")${NC}"
echo ""
echo -e "${YELLOW}Review and edit if needed:${NC}"
echo -e "  nano $ENV_FILE"
echo ""
