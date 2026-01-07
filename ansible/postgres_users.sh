#!/bin/bash
# Deployment script for PostgreSQL user management
# This shows the complete workflow including Bitwarden unlock

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
ANSIBLE_DIR="$SCRIPT_DIR"
INVENTORY_HOST_VARS="$ANSIBLE_DIR/inventory/host_vars/postgresql.yml"
PLAYBOOK="$ANSIBLE_DIR/playbooks/postgresql.yml"
COMPOSE_FILE="$PROJECT_ROOT/stacks/postgresql/docker-compose.yaml"

search_cmd() {
    if command -v rg >/dev/null 2>&1; then
        rg "$@"
    else
        grep "$@"
    fi
}

search_cmd_quiet() {
    if command -v rg >/dev/null 2>&1; then
        rg -q "$@"
    else
        grep -q "$@"
    fi
}

get_yaml_value() {
    local key=$1
    if command -v rg >/dev/null 2>&1; then
        rg -m 1 -o "^${key}:\\s*.*" "$INVENTORY_HOST_VARS" \
            | sed -E "s/^${key}:\\s*['\"]?([^'\"]+)['\"]?.*/\\1/"
    else
        grep -m 1 -E "^${key}:" "$INVENTORY_HOST_VARS" \
            | sed -E "s/^${key}:\\s*['\"]?([^'\"]+)['\"]?.*/\\1/"
    fi
}

wait_for_postgres() {
    local host=$1
    local port=$2
    local attempts=15
    local sleep_s=2

    echo "Waiting for PostgreSQL at ${host}:${port}..."
    for _ in $(seq 1 "$attempts"); do
        if command -v nc >/dev/null 2>&1; then
            if nc -z "$host" "$port" >/dev/null 2>&1; then
                echo "✓ PostgreSQL is reachable"
                return 0
            fi
        else
            if command -v timeout >/dev/null 2>&1; then
                if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1; then
                    echo "✓ PostgreSQL is reachable"
                    return 0
                fi
            else
                if bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" >/dev/null 2>&1; then
                    echo "✓ PostgreSQL is reachable"
                    return 0
                fi
            fi
        fi
        sleep "$sleep_s"
    done

    echo "❌ Unable to reach PostgreSQL at ${host}:${port}"
    return 1
}

echo "=== PostgreSQL User Management Deployment ==="
echo ""

# Step 1: Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
    echo "❌ Error: Bitwarden CLI (bw) is not installed"
    echo "Install it with: npm install -g @bitwarden/cli"
    exit 1
fi

echo "✓ Bitwarden CLI found"

# Step 2: Check if PostgreSQL is reachable
if [ ! -f "$INVENTORY_HOST_VARS" ]; then
    echo "❌ Inventory file not found: $INVENTORY_HOST_VARS"
    exit 1
fi

POSTGRESQL_HOST=$(get_yaml_value "postgresql_host")
POSTGRESQL_PORT=$(get_yaml_value "postgresql_port")
POSTGRESQL_CONNECTION_MODE=$(get_yaml_value "postgresql_connection_mode")
POSTGRESQL_TARGET_HOST=$(get_yaml_value "postgresql_target_host")

POSTGRESQL_HOST=${POSTGRESQL_HOST:-localhost}
POSTGRESQL_PORT=${POSTGRESQL_PORT:-5432}
POSTGRESQL_CONNECTION_MODE=${POSTGRESQL_CONNECTION_MODE:-tcp}
POSTGRESQL_TARGET_HOST=${POSTGRESQL_TARGET_HOST:-localhost}

if [ "$POSTGRESQL_CONNECTION_MODE" = "docker_exec" ]; then
    echo "ℹ️  Docker exec mode enabled; skipping TCP reachability checks"
else
    if [[ "$POSTGRESQL_HOST" == "localhost" || "$POSTGRESQL_HOST" == "127.0.0.1" ]]; then
        if ! docker compose -f "$COMPOSE_FILE" ps postgres | search_cmd_quiet "Up"; then
            echo "⚠️  PostgreSQL container is not running"
            echo "Starting PostgreSQL container..."
            docker compose -f "$COMPOSE_FILE" up -d postgres
            echo "Waiting for PostgreSQL to be ready..."
            sleep 5
        fi

        echo "✓ PostgreSQL container is running"
    else
        wait_for_postgres "$POSTGRESQL_HOST" "$POSTGRESQL_PORT"
    fi
fi

# Step 3: Unlock Bitwarden (if not already unlocked)
if [ -z "${BW_SESSION:-}" ]; then
    echo ""
    echo "🔐 Unlocking Bitwarden..."
    echo "Please enter your master password:"
    if ! BW_SESSION_RAW=$(bw unlock --raw); then
        echo "❌ Failed to unlock Bitwarden (check 'bw login' or server config)"
        exit 1
    fi
    export BW_SESSION="$BW_SESSION_RAW"

    if [ -z "$BW_SESSION" ]; then
        echo "❌ Failed to unlock Bitwarden"
        exit 1
    fi
    
    bw sync --session "$BW_SESSION" >/dev/null 2>&1 || true
    echo "✓ Bitwarden unlocked"
else
    echo "✓ Bitwarden session already active"
fi

# Step 4: Verify Bitwarden items exist (and optionally create missing ones)
echo ""
echo "🔍 Verifying Bitwarden items..."

declare -A ITEM_MAP
ITEM_MAP=()

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && ITEM_MAP["$ITEM"]=1
done < <(
    (search_cmd -o "lookup\\('bitwarden', '[^']+'\\)" "$INVENTORY_HOST_VARS" || true) \
        | sed -E "s/.*'([^']+)'.*/\\1/" \
        | sort -u
)

while IFS= read -r ITEM; do
    [ -n "$ITEM" ] && ITEM_MAP["$ITEM"]=1
done < <(
    (search_cmd -o "bitwarden_item:\\s*['\"][^'\"]+['\"]" "$INVENTORY_HOST_VARS" || true) \
        | sed -E "s/.*['\"]([^'\"]+)['\"]/\\1/" \
        | sort -u
)

if [ "${#ITEM_MAP[@]}" -eq 0 ]; then
    echo "⚠️  No Bitwarden items found in $INVENTORY_HOST_VARS"
    echo "Proceeding without preflight checks."
fi

MISSING_ITEMS=0

for ITEM in "${!ITEM_MAP[@]}"; do
    if ! bw list items --search "$ITEM" --session "$BW_SESSION" | search_cmd_quiet "\"name\""; then
        echo "  ⚠️  Missing: $ITEM"
        MISSING_ITEMS=$((MISSING_ITEMS + 1))

        read -p "  Create Bitwarden item for '$ITEM'? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            PASSWORD=$(bw generate --length 32 --special)
            ITEM_JSON=$(printf '{"type":1,"name":"%s","login":{"username":"","password":"%s"}}' "$ITEM" "$PASSWORD" | bw encode)
            bw create item "$ITEM_JSON" --session "$BW_SESSION" >/dev/null
            echo "  ✓ Created: $ITEM"
        fi
    else
        echo "  ✓ Found: $ITEM"
    fi
done

if [ $MISSING_ITEMS -gt 0 ]; then
    echo ""
    echo "⚠️  Warning: $MISSING_ITEMS item(s) not found in Bitwarden"
    echo "The playbook may fail for missing items"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 5: Run Ansible playbook
echo ""
echo "🚀 Running Ansible playbook..."
echo ""

(
    cd "$ANSIBLE_DIR"
    ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg" ansible-playbook \
        "$PLAYBOOK" \
        -e "BW_SESSION=$BW_SESSION" \
        -e "postgresql_target_host=$POSTGRESQL_TARGET_HOST"
)

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Note: BW_SESSION is exported in your current shell."
echo "   To use in other terminals, run:"
echo "   export BW_SESSION=$BW_SESSION"
