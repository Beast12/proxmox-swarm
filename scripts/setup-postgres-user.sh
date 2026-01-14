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
    echo -e "${BLUE}Usage:${NC} $0 <username> <database> [password]"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 dockhand dockhand"
    echo "  $0 authentik authentik 'mySecurePassword123!'"
    echo ""
    echo -e "${YELLOW}If password is not provided, one will be generated.${NC}"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DB_USER="$1"
DB_NAME="$2"
DB_PASSWORD="${3:-$(openssl rand -base64 32)}"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL User Setup                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Find PostgreSQL container
echo -e "${YELLOW}→ Finding PostgreSQL container...${NC}"

# Try different methods to find the container
CONTAINER=""

# Method 1: Try by service label
if [ -z "$CONTAINER" ]; then
    CONTAINER=$(docker ps -q -f "label=com.docker.swarm.service.name=postgresql_postgres" 2>/dev/null | head -n1)
fi

# Method 2: Try by name filter
if [ -z "$CONTAINER" ]; then
    CONTAINER=$(docker ps -qf "name=postgresql_postgres" 2>/dev/null | head -n1)
fi

# Method 3: Try to find in postgresql stack namespace
if [ -z "$CONTAINER" ]; then
    CONTAINER=$(docker ps -qf "label=com.docker.stack.namespace=postgresql" 2>/dev/null | while read cid; do
        name=$(docker inspect --format='{{.Name}}' "$cid" 2>/dev/null)
        if echo "$name" | grep -q "postgres" && ! echo "$name" | grep -qE "exporter|pgadmin"; then
            echo "$cid"
            break
        fi
    done | head -n1)
fi

if [ -z "$CONTAINER" ]; then
    echo -e "${RED}✗ PostgreSQL container not found${NC}"
    echo -e "${YELLOW}  PostgreSQL service appears to be running but container not found.${NC}"
    echo ""
    echo -e "${YELLOW}  Services:${NC}"
    docker service ls --filter "name=postgresql" --format "table {{.Name}}\t{{.Replicas}}"
    echo ""
    echo -e "${YELLOW}  Containers:${NC}"
    docker ps --filter "label=com.docker.stack.namespace=postgresql" --format "table {{.Names}}\t{{.ID}}\t{{.Status}}" 2>/dev/null || echo "  None found"
    exit 1
fi

echo -e "${GREEN}✓ Found container: $CONTAINER${NC}\n"

# Check if user already exists
echo -e "${YELLOW}→ Checking if user exists...${NC}"
USER_EXISTS=$(docker exec "$CONTAINER" psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';" || echo "0")

if [ "$USER_EXISTS" = "1" ]; then
    echo -e "${YELLOW}  ⚠ User '$DB_USER' already exists${NC}"
    read -p "  Update password? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Skipping user creation${NC}\n"
    else
        echo -e "${YELLOW}  → Updating password...${NC}"
        docker exec "$CONTAINER" psql -U postgres -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null
        echo -e "${GREEN}  ✓ Password updated${NC}\n"
    fi
else
    echo -e "${YELLOW}→ Creating user '$DB_USER'...${NC}"
    docker exec "$CONTAINER" psql -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null
    echo -e "${GREEN}✓ User created${NC}\n"
fi

# Check if database exists
echo -e "${YELLOW}→ Checking if database exists...${NC}"
DB_EXISTS=$(docker exec "$CONTAINER" psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" || echo "0")

if [ "$DB_EXISTS" = "1" ]; then
    echo -e "${BLUE}  ℹ Database '$DB_NAME' already exists${NC}\n"
else
    echo -e "${YELLOW}→ Creating database '$DB_NAME'...${NC}"
    docker exec "$CONTAINER" psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" > /dev/null
    echo -e "${GREEN}✓ Database created${NC}\n"
fi

# Grant privileges
echo -e "${YELLOW}→ Granting privileges...${NC}"
docker exec "$CONTAINER" psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" > /dev/null
echo -e "${GREEN}✓ Privileges granted${NC}\n"

# Test connection
echo -e "${YELLOW}→ Testing connection...${NC}"
if docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection test successful${NC}\n"
else
    echo -e "${RED}✗ Connection test failed${NC}\n"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Database Setup Complete                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Database Details:${NC}"
echo -e "  User:     ${GREEN}$DB_USER${NC}"
echo -e "  Database: ${GREEN}$DB_NAME${NC}"
echo -e "  Password: ${YELLOW}$DB_PASSWORD${NC}"
echo ""
echo -e "${BLUE}Connection String:${NC}"
echo -e "  ${YELLOW}postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}${NC}"
echo ""
echo -e "${RED}⚠ Save this password securely! It won't be shown again.${NC}"
echo ""