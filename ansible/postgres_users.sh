#!/bin/bash
# Deployment script for PostgreSQL user management
# This shows the complete workflow including Bitwarden unlock

set -e

echo "=== PostgreSQL User Management Deployment ==="
echo ""

# Step 1: Check if Bitwarden CLI is installed
if ! command -v bw &> /dev/null; then
    echo "❌ Error: Bitwarden CLI (bw) is not installed"
    echo "Install it with: npm install -g @bitwarden/cli"
    exit 1
fi

echo "✓ Bitwarden CLI found"

# Step 2: Check if Docker container is running
if ! docker compose ps postgres | grep -q "Up"; then
    echo "⚠️  PostgreSQL container is not running"
    echo "Starting PostgreSQL container..."
    docker compose up -d postgres
    echo "Waiting for PostgreSQL to be ready..."
    sleep 5
fi

echo "✓ PostgreSQL container is running"

# Step 3: Unlock Bitwarden (if not already unlocked)
if [ -z "$BW_SESSION" ]; then
    echo ""
    echo "🔐 Unlocking Bitwarden..."
    echo "Please enter your master password:"
    export BW_SESSION=$(bw unlock --raw)
    
    if [ -z "$BW_SESSION" ]; then
        echo "❌ Failed to unlock Bitwarden"
        exit 1
    fi
    
    echo "✓ Bitwarden unlocked"
else
    echo "✓ Bitwarden session already active"
fi

# Step 4: Verify Bitwarden items exist
echo ""
echo "🔍 Verifying Bitwarden items..."

ITEMS_TO_CHECK=(
    "PostgreSQL Admin"
    "Nextcloud Database"
    "Immich Database"
    "Authentik Database"
)

MISSING_ITEMS=0

for ITEM in "${ITEMS_TO_CHECK[@]}"; do
    if ! bw list items --search "$ITEM" --session "$BW_SESSION" | grep -q "\"name\":"; then
        echo "  ⚠️  Missing: $ITEM"
        MISSING_ITEMS=$((MISSING_ITEMS + 1))
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

ansible-playbook \
    -i inventory \
    site.yml \
    --tags postgresql \
    -e "BW_SESSION=$BW_SESSION"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Note: BW_SESSION is exported in your current shell."
echo "   To use in other terminals, run:"
echo "   export BW_SESSION=$BW_SESSION"