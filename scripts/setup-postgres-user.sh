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
    echo -e "${BLUE}Remote execution:${NC}"
    echo "  DOCKER_HOST_OVERRIDE=ssh://user@swarm-worker-w2 $0 dockhand dockhand"
    echo "  DOCKER_SSH_USER=koen $0 dockhand dockhand"
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

SERVICE_NAME="postgresql_postgres"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DOCKER_SSH_USER="${DOCKER_SSH_USER:-$USER}"

docker_cmd() {
    if [ -n "${DOCKER_HOST_OVERRIDE:-}" ]; then
        "$DOCKER_BIN" -H "$DOCKER_HOST_OVERRIDE" "$@"
    else
        "$DOCKER_BIN" "$@"
    fi
}

get_running_node() {
    docker_cmd service ps "$SERVICE_NAME" --format "{{.Node}} {{.CurrentState}}" 2>/dev/null | \
        awk '$2 ~ /^Running/ {print $1; exit}'
}

get_local_node_name() {
    docker_cmd info -f "{{.Name}}" 2>/dev/null || true
}

get_target_docker_host() {
    if [ -n "${DOCKER_HOST_OVERRIDE:-}" ]; then
        echo "$DOCKER_HOST_OVERRIDE"
        return 0
    fi
    local node
    node="$(get_running_node)"
    if [ -z "$node" ]; then
        return 1
    fi
    local local_node
    local_node="$(get_local_node_name)"
    if [ -n "$local_node" ] && [ "$node" = "$local_node" ]; then
        echo ""
        return 0
    fi
    local node_addr
    node_addr="$(docker_cmd node inspect "$node" --format '{{.Status.Addr}}' 2>/dev/null || true)"
    if [ -n "$node_addr" ]; then
        echo "ssh://${DOCKER_SSH_USER}@${node_addr}"
        return 0
    fi
    echo "ssh://${DOCKER_SSH_USER}@${node}"
}

docker_target_cmd() {
    local target_host="$1"
    shift
    if [ -n "$target_host" ]; then
        "$DOCKER_BIN" -H "$target_host" "$@"
    else
        "$DOCKER_BIN" "$@"
    fi
}

get_container_name_on_target() {
    local target_host="$1"
    docker_target_cmd "$target_host" ps --filter "name=${SERVICE_NAME}.1" --format "{{.Names}}" 2>/dev/null | head -n 1
}

run_psql() {
    local db_name="${1:-}"
    local sql="${2:-}"
    local db_args=()
    if [ -n "$db_name" ]; then
        db_args=(-d "$db_name")
    fi
    local target_host
    target_host="$(get_target_docker_host)" || {
        echo "Unable to determine running node for ${SERVICE_NAME}." 1>&2
        return 1
    }
    local container_name
    container_name="$(get_container_name_on_target "$target_host")"
    if [ -z "$container_name" ]; then
        echo "Unable to find ${SERVICE_NAME} container on target host." 1>&2
        echo "Set DOCKER_HOST_OVERRIDE (e.g. tcp://host:2375) or DOCKER_SSH_USER to reach the node." 1>&2
        return 1
    fi
    local output
    if ! output="$(docker_target_cmd "$target_host" exec -i "$container_name" psql -v ON_ERROR_STOP=1 -U postgres "${db_args[@]}" -c "$sql" 2>&1)"; then
        if echo "$output" | grep -q "No such container"; then
            container_name="$(get_container_name_on_target "$target_host")"
            if [ -n "$container_name" ]; then
                output="$(docker_target_cmd "$target_host" exec -i "$container_name" psql -v ON_ERROR_STOP=1 -U postgres "${db_args[@]}" -c "$sql" 2>&1)" || {
                    echo "$output"
                    return 1
                }
                echo "$output"
                return 0
            fi
        fi
        echo "$output"
        return 1
    fi
    echo "$output"
    return 0
}

# Check if service exists
echo -e "${YELLOW}→ Checking PostgreSQL service...${NC}"
if ! docker_cmd service ls --format "{{.Name}}" | grep -q "^${SERVICE_NAME}$"; then
    echo -e "${RED}✗ PostgreSQL service not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Service found${NC}\n"

# Check if user exists
echo -e "${YELLOW}→ Checking if user exists...${NC}"
if ! user_check_output="$(run_psql "" "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';" 2>&1)"; then
    echo -e "${RED}✗ Failed to query roles${NC}"
    echo "$user_check_output"
    exit 1
fi

if echo "$user_check_output" | grep -q "^1$"; then
    echo -e "${YELLOW}  ⚠ User '$DB_USER' already exists${NC}"
    read -p "  Update password? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}  Skipping user${NC}\n"
    else
        echo -e "${YELLOW}  → Updating password...${NC}"
        if output="$(run_psql "" "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>&1)"; then
            echo "$output" | grep -q "ALTER ROLE" && \
                echo -e "${GREEN}  ✓ Password updated${NC}\n" || \
                echo -e "${GREEN}  ✓ Password updated${NC}\n"
        else
            echo -e "${RED}  ✗ Failed to update password${NC}"
            echo "$output"
            echo ""
        fi
    fi
else
    echo -e "${YELLOW}→ Creating user '$DB_USER'...${NC}"
    if output="$(run_psql "" "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>&1)"; then
        echo "$output" | grep -q "CREATE ROLE" && \
            echo -e "${GREEN}✓ User created${NC}\n" || \
            echo -e "${GREEN}✓ User created${NC}\n"
    else
        echo -e "${RED}✗ Failed to create user${NC}"
        echo "$output"
        echo ""
    fi
fi

# Check if database exists
echo -e "${YELLOW}→ Checking if database exists...${NC}"
if ! db_check_output="$(run_psql "" "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';" 2>&1)"; then
    echo -e "${RED}✗ Failed to query databases${NC}"
    echo "$db_check_output"
    exit 1
fi

if echo "$db_check_output" | grep -q "^1$"; then
    echo -e "${BLUE}  ℹ Database '$DB_NAME' already exists${NC}\n"
else
    echo -e "${YELLOW}→ Creating database '$DB_NAME'...${NC}"
    if output=$(run_psql "" "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>&1); then
        echo "$output" | grep -q "CREATE DATABASE" && \
            echo -e "${GREEN}✓ Database created${NC}\n" || \
            echo -e "${GREEN}✓ Database created${NC}\n"
    else
        echo -e "${RED}✗ Failed to create database${NC}"
        echo "$output"
        echo ""
    fi
fi

# Ensure database owner
echo -e "${YELLOW}→ Ensuring database owner...${NC}"
run_psql "" "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};" 2>&1 | grep -q "ALTER DATABASE" && \
    echo -e "${GREEN}✓ Database owner set${NC}" || \
    echo -e "${YELLOW}⚠ Database owner may already be set${NC}"

# Grant privileges
echo -e "${YELLOW}→ Granting database privileges...${NC}"
run_psql "" "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Database privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Database privileges may already be set${NC}"

# Grant schema creation privilege
echo -e "${YELLOW}→ Granting schema creation privilege...${NC}"
run_psql "${DB_NAME}" "GRANT CREATE ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Schema creation privilege granted${NC}" || \
    echo -e "${YELLOW}⚠ Schema creation privilege may already be set${NC}"

# Grant public schema usage
echo -e "${YELLOW}→ Granting public schema privileges...${NC}"
run_psql "${DB_NAME}" "ALTER SCHEMA public OWNER TO ${DB_USER};" 2>&1 | grep -q "ALTER SCHEMA" && \
    echo -e "${GREEN}✓ Public schema owner set${NC}" || \
    echo -e "${YELLOW}⚠ Public schema owner may already be set${NC}"

run_psql "${DB_NAME}" "GRANT ALL ON SCHEMA public TO ${DB_USER};" 2>&1 | grep -q "GRANT" && \
    echo -e "${GREEN}✓ Public schema privileges granted${NC}\n" || \
    echo -e "${YELLOW}⚠ Public schema privileges may already be set${NC}\n"

echo -e "${YELLOW}→ Granting default privileges for future objects...${NC}"
run_psql "${DB_NAME}" "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
    echo -e "${GREEN}✓ Default table privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Default table privileges may already be set${NC}"
run_psql "${DB_NAME}" "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
    echo -e "${GREEN}✓ Default sequence privileges granted${NC}" || \
    echo -e "${YELLOW}⚠ Default sequence privileges may already be set${NC}"
run_psql "${DB_NAME}" "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_USER};" 2>&1 | grep -q "ALTER DEFAULT PRIVILEGES" && \
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
