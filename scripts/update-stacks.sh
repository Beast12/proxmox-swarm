#!/bin/bash

STACKS_DIR=~/proxmox-swarm/stacks
ACTIVE_STACKS=($(docker stack ls --format '{{.Name}}'))

if [ ${#ACTIVE_STACKS[@]} -eq 0 ]; then
    echo "No running stacks found."
    exit 0
fi

cd $STACKS_DIR

for stack in "${ACTIVE_STACKS[@]}"; do
    echo "======================================"
    echo "Updating stack: $stack"
    echo "======================================"
    
    if [ -f "$stack/docker-compose.yaml" ]; then
        docker stack deploy -c "$stack/docker-compose.yaml" "$stack"
        echo "✓ Updated $stack"
    elif [ -f "$stack/docker-compose.yml" ]; then
        docker stack deploy -c "$stack/docker-compose.yml" "$stack"
        echo "✓ Updated $stack"
    elif [ -f "$stack/compose.yaml" ]; then
        docker stack deploy -c "$stack/compose.yaml" "$stack"
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
