#!/bin/bash

set -euo pipefail

CONTAINERS_DIR="/containers"

function log() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function launch_all_containers() {
    log "Launching all container stacks..."

    for dir in reverse-proxy homarr portainer dockge pbx; do
        COMPOSE_FILE="$CONTAINERS_DIR/$dir/docker-compose.yml"
        if [ -f "$COMPOSE_FILE" ]; then
            log "Starting $dir..."
            docker compose -f "$COMPOSE_FILE" pull
            docker compose -f "$COMPOSE_FILE" up -d
        else
            log "Skipping $dir — no docker-compose.yml found."
        fi
    done

    log "Launching tenant containers..."
    for tenant in "$CONTAINERS_DIR/tenants/"*/; do
        COMPOSE_FILE="${tenant}docker-compose.yml"
        if [ -f "$COMPOSE_FILE" ]; then
            log "Starting tenant: $(basename "$tenant")"
            docker compose -f "$COMPOSE_FILE" pull
            docker compose -f "$COMPOSE_FILE" up -d
        fi
    done

    log "✅ All containers launched."
}

launch_all_containers
