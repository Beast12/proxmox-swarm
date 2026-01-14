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
DB_PASSWORD="${3:-$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')}"

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

# Ensure database owner
echo -e "${YELLOW}→ Ensuring database owner...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" 2>&1 | grep -q "ALTER DATABASE" && \
    echo -e "${GREEN}✓ Database owner set${NC}" || \
    echo -e "${YELLOW}⚠ Database owner may already be set${NC}"

# Grant privileges
echo -e "${YELLOW}→ Granting database privileges...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Database privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Database privileges may already be set${NC}"

# Grant schema creation privilege
echo -e "${YELLOW}→ Granting schema creation privilege...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT CREATE ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Schema creation privilege granted${NC}" || \
    echo -e "${YELLOW}⚠ Schema creation privilege may already be set${NC}"

# Grant public schema usage
echo -e "${YELLOW}→ Granting public schema privileges...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER SCHEMA public OWNER TO ${DB_USER};" 2>&1 | grep -q "ALTER SCHEMA" && \
    echo -e "${GREEN}✓ Public schema owner set${NC}" || \
    echo -e "${YELLOW}⚠ Public schema owner may already be set${NC}"

docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "GRANT ALL ON SCHEMA public TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Public schema privileges granted${NC}\n" || \
    echo -e "${YELLOW}⚠ Public schema privileges may already be set${NC}\n"

echo -e "${YELLOW}→ Granting default privileges for future objects...${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
    echo -e "${GREEN}✓ Default table privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Default table privileges may already be set${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
    echo -e "${GREEN}✓ Default sequence privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Default sequence privileges may already be set${NC}"
docker service exec -T postgresql_postgres psql -U postgres -d ${DB_NAME} -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
    echo -e "${GREEN}✓ Default function privileges granted${NC}\n" || \
    echo -e "${YELLOW}⚠ Default function privileges may already be set${NC}\n"

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
