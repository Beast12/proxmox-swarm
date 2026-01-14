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

# Find the actual running container
echo -e "${YELLOW}→ Finding PostgreSQL container...${NC}"

# Get the node and task for the postgresql service
NODE_TASK=$(docker service ps postgresql_postgres --filter "desired-state=running" --format "{{.Node}}\t{{.Name}}" 2>/dev/null | head -n1)

if [ -z "$NODE_TASK" ]; then
    echo -e "${RED}✗ PostgreSQL service is not running${NC}"
    exit 1
fi

NODE=$(echo "$NODE_TASK" | awk '{print $1}')
TASK=$(echo "$NODE_TASK" | awk '{print $2}')

echo -e "${GREEN}✓ Found running on node: $NODE${NC}"

# Get container ID from the task name
CONTAINER=$(docker ps -q --filter "name=$TASK" 2>/dev/null | head -n1)

if [ -z "$CONTAINER" ]; then
    echo -e "${RED}✗ Could not find container for task: $TASK${NC}"
    echo -e "${YELLOW}  Trying alternative method...${NC}"
    CONTAINER=$(docker ps --format "{{.ID}}\t{{.Names}}" | grep postgresql | grep postgres | grep -v exporter | grep -v pgadmin | head -n1 | awk '{print $1}')
fi

if [ -z "$CONTAINER" ]; then
    echo -e "${RED}✗ PostgreSQL container not found${NC}"
    echo ""
    echo -e "${YELLOW}Available containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.ID}}\t{{.Status}}"
    exit 1
fi

echo -e "${GREEN}✓ Found container: $CONTAINER${NC}\n"

# Function to execute psql commands
exec_psql() {
    local sql="$1"
    docker exec -i "$CONTAINER" psql -U postgres -tc "$sql" 2>/dev/null | tr -d ' '
}

# Check if user already exists
echo -e "${YELLOW}→ Checking if user exists...${NC}"
USER_EXISTS=$(exec_psql "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';" || echo "")

if [ "$USER_EXISTS" = "1" ]; then
    echo -e "${YELLOW}  ⚠ User '$DB_USER' already exists${NC}"
    read -p "  Update password? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}  → Updating password...${NC}"
        docker exec "$CONTAINER" psql -U postgres -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null 2>&1
        echo -e "${GREEN}  ✓ Password updated${NC}\n"
    else
        echo -e "${BLUE}  Skipping password update${NC}\n"
    fi
else
    echo -e "${YELLOW}→ Creating user '$DB_USER'...${NC}"
    docker exec "$CONTAINER" psql -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null 2>&1
    echo -e "${GREEN}✓ User created${NC}\n"
fi

# Check if database exists
echo -e "${YELLOW}→ Checking if database exists...${NC}"
DB_EXISTS=$(exec_psql "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" || echo "")

if [ "$DB_EXISTS" = "1" ]; then
    echo -e "${BLUE}  ℹ Database '$DB_NAME' already exists${NC}\n"
else
    echo -e "${YELLOW}→ Creating database '$DB_NAME'...${NC}"
    docker exec "$CONTAINER" psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" > /dev/null 2>&1
    echo -e "${GREEN}✓ Database created${NC}\n"
fi

# Grant privileges
echo -e "${YELLOW}→ Granting privileges...${NC}"
docker exec "$CONTAINER" psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" > /dev/null 2>&1
echo -e "${GREEN}✓ Privileges granted${NC}\n"

# Test connection
echo -e "${YELLOW}→ Testing connection...${NC}"
if docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection test successful${NC}\n"
else
    echo -e "${YELLOW}⚠ Connection test skipped${NC}\n"
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