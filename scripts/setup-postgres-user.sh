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
    exit 1
}

if [ $# -lt 2 ]; then
    usage
fi

DB_USER="$1"
DB_NAME="$2"
# Generate alphanumeric password only (no special characters that could cause issues)
DB_PASSWORD="${3:-$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32)}"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  PostgreSQL User Setup                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

# Check if service exists
echo -e "${YELLOW}→ Checking PostgreSQL service...${NC}"
if ! docker service ls --format "{{.Name}}" | grep -q "^postgresql_postgres$"; then
    echo -e "${RED}✗ PostgreSQL service not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Service found${NC}\n"

# Check if user exists
echo -e "${YELLOW}→ Checking if user exists...${NC}"
USER_CHECK=$(docker service exec -T postgresql_postgres psql -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';" 2>&1 | grep -c "^1$" || echo "0")

if [ "$USER_CHECK" != "0" ]; then
    echo -e "${YELLOW}  ⚠ User '$DB_USER' already exists${NC}"
    read -p "  Update password? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Skipping user${NC}\n"
    else
        echo -e "${YELLOW}  → Updating password...${NC}"
        docker service exec -T postgresql_postgres psql -U postgres -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>&1 | grep -q "ALTER ROLE" && \
            echo -e "${GREEN}  ✓ Password updated${NC}\n" || \
            echo -e "${RED}  ✗ Failed to update password${NC}\n"
    fi
else
    echo -e "${YELLOW}→ Creating user '$DB_USER'...${NC}"
    docker service exec -T postgresql_postgres psql -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>&1 | grep -q "CREATE ROLE" && \
        echo -e "${GREEN}✓ User created${NC}\n" || \
        echo -e "${RED}✗ Failed to create user${NC}\n"
fi

# Check if database exists
echo -e "${YELLOW}→ Checking if database exists...${NC}"
DB_CHECK=$(docker service exec -T postgresql_postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" 2>&1 | grep -c "^1$" || echo "0")

if [ "$DB_CHECK" != "0" ]; then
    echo -e "${BLUE}  ℹ Database '$DB_NAME' already exists${NC}\n"
else
    echo -e "${YELLOW}→ Creating database '$DB_NAME'...${NC}"
    docker service exec -T postgresql_postgres psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>&1 | grep -q "CREATE DATABASE" && \
        echo -e "${GREEN}✓ Database created${NC}\n" || \
        echo -e "${RED}✗ Failed to create database${NC}\n"
fi

# Grant privileges
echo -e "${YELLOW}→ Granting full database privileges...${NC}"

# 1. Grant all privileges on the database itself
docker service exec -T postgresql_postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" >/dev/null 2>&1
echo -e "${GREEN}  ✓ Database privileges${NC}"

# 2. Make user owner of the database (ensures full control)
docker service exec -T postgresql_postgres psql -U postgres -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" >/dev/null 2>&1
echo -e "${GREEN}  ✓ Database ownership${NC}"

# 3. Grant schema creation privilege
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT CREATE ON DATABASE ${DB_NAME} TO ${DB_USER};" >/dev/null 2>&1
echo -e "${GREEN}  ✓ Schema creation privilege${NC}"

# 4. Grant all privileges on public schema
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" >/dev/null 2>&1
echo -e "${GREEN}  ✓ Public schema privileges${NC}"

# 5. Grant privileges on all tables in public schema (current and future)
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_USER};" >/dev/null 2>&1
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};" >/dev/null 2>&1
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};" >/dev/null 2>&1
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};" >/dev/null 2>&1
echo -e "${GREEN}  ✓ Table and sequence privileges${NC}"

# 6. Grant CREATEDB role attribute (allows creating additional databases if needed)
docker service exec -T postgresql_postgres psql -U postgres -c "ALTER USER ${DB_USER} CREATEDB;" >/dev/null 2>&1
echo -e "${GREEN}  ✓ CREATEDB role attribute${NC}\n"

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