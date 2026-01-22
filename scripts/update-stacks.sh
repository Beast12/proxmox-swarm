# Script to update all Docker stacks
#!/bin/bash

STACKS_DIR=~/proxmox-swarm/stacks
ACTIVE_STACKS=(authentik dev-tools monitoring postgresql services tools traefik)

cd $STACKS_DIR

for stack in "${ACTIVE_STACKS[@]}"; do
    echo "======================================"
    echo "Updating stack: $stack"
    echo "======================================"
    
    if [ -f "$stack/docker-compose.yml" ]; then
        docker stack deploy -c "$stack/docker-compose.yml" "$stack"
        echo "✓ Updated $stack"
    elif [ -f "$stack/compose.yml" ]; then
        docker stack deploy -c "$stack/compose.yml" "$stack"
        echo "✓ Updated $stack"
    else
        echo "✗ No compose file found for $stack"
    fi
    
    echo ""
done

echo "======================================"
echo "All stacks updated!"
echo "======================================"
docker stack ls