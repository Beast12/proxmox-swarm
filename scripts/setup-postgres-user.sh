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

# Find the service
echo -e "${YELLOW}→ Checking PostgreSQL service...${NC}"
if ! docker service ls --format "{{.Name}}" | grep -q "^postgresql_postgres$"; then
    echo -e "${RED}✗ PostgreSQL service not found${NC}"
    echo -e "${YELLOW}  Available services:${NC}"
    docker service ls | grep postgresql || echo "  No postgresql services found"
    exit 1
fi

# Get the task ID and execute commands via docker service exec
SERVICE_NAME="postgresql_postgres"
echo -e "${GREEN}✓ Found service: $SERVICE_NAME${NC}\n"

# Function to execute psql commands via service
exec_psql() {
    local sql="$1"
    docker service exec -i "$SERVICE_NAME" psql -U postgres -c "$sql" 2>&1
}

# Check if user already exists
echo -e "${YELLOW}→ Checking if user exists...${NC}"
USER_EXISTS=$(exec_psql "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';" | grep -c "1 row" || echo "0")

if [ "$USER_EXISTS" != "0" ]; then
    echo -e "${YELLOW}  ⚠ User '$DB_USER' already exists${NC}"
    read -p "  Update password? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}  → Updating password...${NC}"
        exec_psql "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null
        echo -e "${GREEN}  ✓ Password updated${NC}\n"
    else
        echo -e "${BLUE}  Skipping user creation${NC}\n"
    fi
else
    echo -e "${YELLOW}→ Creating user '$DB_USER'...${NC}"
    exec_psql "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" > /dev/null
    echo -e "${GREEN}✓ User created${NC}\n"
fi

# Check if database exists
echo -e "${YELLOW}→ Checking if database exists...${NC}"
DB_EXISTS=$(exec_psql "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" | grep -c "1 row" || echo "0")

if [ "$DB_EXISTS" != "0" ]; then
    echo -e "${BLUE}  ℹ Database '$DB_NAME' already exists${NC}\n"
else
    echo -e "${YELLOW}→ Creating database '$DB_NAME'...${NC}"
    exec_psql "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" > /dev/null
    echo -e "${GREEN}✓ Database created${NC}\n"
fi

# Grant privileges
echo -e "${YELLOW}→ Granting privileges...${NC}"
exec_psql "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" > /dev/null
echo -e "${GREEN}✓ Privileges granted${NC}\n"

# Test connection
echo -e "${YELLOW}→ Testing connection...${NC}"
if docker service exec -i "$SERVICE_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Connection test successful${NC}\n"
else
    echo -e "${RED}✗ Connection test failed${NC}\n"
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