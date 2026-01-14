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
    echo "  $0 authentik authentik myPassword123"
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DB_USER="$1"
DB_NAME="$2"
# Generate alphanumeric password only (no special characters)
DB_PASSWORD="${3:-$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)}"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL User Setup v2                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Check if service exists
echo -e "${YELLOW}→ Checking PostgreSQL service...${NC}"
if ! docker service ls --format "{{.Name}}" | grep -q "^postgresql_postgres$"; then
    echo -e "${RED}✗ PostgreSQL service not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Service found${NC}\n"

# SQL commands to execute
SQL_COMMANDS="
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}') THEN
        CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}' CREATEDB;
        RAISE NOTICE 'User created';
    ELSE
        ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}' CREATEDB;
        RAISE NOTICE 'User updated';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE ${DB_NAME} OWNER ${DB_USER}'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}')
\gexec

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};
ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};
"

echo -e "${YELLOW}→ Executing setup commands...${NC}"
if echo "$SQL_COMMANDS" | docker service exec -T postgresql_postgres psql -U postgres 2>&1 | grep -q "GRANT\|ALTER DATABASE\|NOTICE"; then
    echo -e "${GREEN}✓ Setup completed${NC}\n"
else
    echo -e "${RED}✗ Setup may have failed - check manually${NC}\n"
fi

# Grant schema privileges on the database
echo -e "${YELLOW}→ Setting up schema privileges...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "
GRANT ALL ON SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};
" >/dev/null 2>&1
echo -e "${GREEN}✓ Schema privileges set${NC}\n"

echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup Complete                                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}\n"

echo -e "${BLUE}Database Details:${NC}"
echo -e "  User:     ${GREEN}$DB_USER${NC}"
echo -e "  Database: ${GREEN}$DB_NAME${NC}"
echo -e "  Password: ${YELLOW}$DB_PASSWORD${NC}"
echo ""
echo -e "${BLUE}Connection String:${NC}"
echo -e "  ${YELLOW}postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}${NC}"
echo ""
echo -e "${BLUE}Privileges Granted:${NC}"
echo -e "  ${GREEN}✓${NC} Database ownership"
echo -e "  ${GREEN}✓${NC} Schema creation (CREATEDB role)"
echo -e "  ${GREEN}✓${NC} All privileges on public schema"
echo -e "  ${GREEN}✓${NC} All privileges on tables/sequences"
echo -e "  ${GREEN}✓${NC} Default privileges for future objects"
echo ""