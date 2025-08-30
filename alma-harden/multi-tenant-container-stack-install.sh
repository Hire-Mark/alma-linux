#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
BASE_DOMAIN="lab.hire-mark.com"
TENANT_DOMAIN1="tnt.hire-mark.com"
TENANT_DOMAIN2="vps.h3webelements.com"
TENANT_DOMAINS=("$TENANT_DOMAIN1" "$TENANT_DOMAIN2")
CONTAINERS_DIR="/containers"
REVERSE_PROXY_DIR="$CONTAINERS_DIR/reverse-proxy"
HOMARR_DIR="$CONTAINERS_DIR/homarr"
COCKPIT_DIR="$CONTAINERS_DIR/cockpit"
PORTAINER_DIR="$CONTAINERS_DIR/portainer"
DOCKGE_DIR="$CONTAINERS_DIR/dockge"
PBX_DIR="$CONTAINERS_DIR/pbx"
TENANTS_DIR="$CONTAINERS_DIR/tenants"
NGINX_CONF_DIR="$REVERSE_PROXY_DIR/nginx/conf.d"

# === FUNCTIONS ===
function log() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function fail() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit 1
}

function install_docker_stack() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker is already installed. Skipping."
    return
  fi
  log "Installing Docker and Docker Compose..."
  dnf install -y dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable --now docker
  log "Docker installed."
}

function setup_directories() {
    log "Setting up container directories..."
    mkdir -p "$REVERSE_PROXY_DIR" "$HOMARR_DIR" "$COCKPIT_DIR" "$PORTAINER_DIR" "$DOCKGE_DIR" "$PBX_DIR" "$TENANTS_DIR"
}

function deploy_reverse_proxy() {
  if docker ps --format '{{.Names}}' | grep -q '^reverse-proxy$'; then
    log "Reverse proxy is already running. Skipping."
    return
  fi
  log "Deploying NGINX reverse proxy with Certbot..."
  mkdir -p "$REVERSE_PROXY_DIR/nginx/conf.d"
  generate_nginx_configs
  cat > "$REVERSE_PROXY_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: reverse-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    depends_on: []
    restart: always
  certbot:
    image: certbot/certbot
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    entrypoint: ""
    command: "tail -f /dev/null"
EOF
}

function deploy_homarr() {
  if docker ps --format '{{.Names}}' | grep -q '^homarr$'; then
    log "Homarr is already running. Skipping."
    return
  fi
  log "Deploying Homarr..."
  cat > "$HOMARR_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  homarr:
    image: ghcr.io/ajnart/homarr:latest
    container_name: homarr
    ports:
      - "7575:7575"
    volumes:
      - ./data:/app/data/configs
    environment:
      - BASE_URL=https://$BASE_DOMAIN
    restart: always
EOF
}

function deploy_cockpit() {
  if docker ps --format '{{.Names}}' | grep -q '^cockpit$'; then
    log "Cockpit is already running. Skipping."
    return
  fi
  log "Deploying Cockpit (via podman/cockpit-ws)..."
  cat > "$COCKPIT_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  cockpit:
    image: ghcr.io/cockpit-project/cockpit:latest
    container_name: cockpit
    ports:
      - "9090:9090"
    restart: always
EOF
}

function deploy_portainer() {
  if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
    log "Portainer is already running. Skipping."
    return
  fi
  log "Deploying Portainer as a container..."
  mkdir -p "$PORTAINER_DIR"
  cat > "$PORTAINER_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    ports:
      - "9443:9443"
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    restart: always
volumes:
  portainer_data:
EOF
    docker compose -f "$PORTAINER_DIR/docker-compose.yml" up -d
    log "Portainer deployed as a container."
}

function deploy_dockge() {
  if docker ps --format '{{.Names}}' | grep -q '^dockge$'; then
    log "Dockge is already running. Skipping."
    return
  fi
  log "Deploying Dockge..."
  cat > "$DOCKGE_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    ports:
      - "5001:5001"
    volumes:
      - ./data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
    restart: always
EOF
}

function deploy_pbx() {
  if docker ps --format '{{.Names}}' | grep -q '^pbx$'; then
    log "PBX is already running. Skipping."
    return
  fi
  log "Deploying FreePBX (tiredofit/freepbx)..."
  cat > "$PBX_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  pbx:
    image: tiredofit/freepbx:latest
    container_name: pbx
    ports:
      - "5060:5060/udp"
      - "5160:5160/udp"
      - "18000-18100:18000-18100/udp"
      - "8080:80"
      - "8443:443"
    environment:
      - RTP_START=18000
      - RTP_FINISH=18100
      - ASTERISK_VERSION=18
    restart: always
EOF
}

function configure_nginx_for_services() {
  log "NGINX subdomain routing is disabled. No configs generated."
}

function configure_homarr() {
    log "Configuring Homarr dashboard for service links..."
    mkdir -p "$HOMARR_DIR/data"
    {
      echo "["
      echo "  { \"name\": \"Homarr\",    \"url\": \"http://$BASE_DOMAIN:7575\" },"
      echo "  { \"name\": \"Cockpit\",   \"url\": \"http://$BASE_DOMAIN:9090\" },"
      echo "  { \"name\": \"Portainer\", \"url\": \"http://$BASE_DOMAIN:9443\" },"
      echo "  { \"name\": \"Dockge\",    \"url\": \"http://$BASE_DOMAIN:5001\" },"
      echo "  { \"name\": \"PBX\",       \"url\": \"http://$BASE_DOMAIN:5060\" }"
      TENANTS_SAFE=("${TENANT_DOMAINS[@]:-}")
      if [[ ${#TENANTS_SAFE[@]} -gt 0 && -n "${TENANTS_SAFE[0]}" ]]; then
        for t in "${TENANTS_SAFE[@]}"; do
          echo ",  { \"name\": \"Tenant: $t\", \"url\": \"http://$BASE_DOMAIN:8080\" }"
        done
      fi
      echo "]"
    } > "$HOMARR_DIR/data/services.json"
}

function deploy_tenants_example() {
    log "Creating example tenant folders and configs..."
    for t in "${TENANT_DOMAINS[@]}"; do
      # Organize each tenant into its own folder named after the domain
      FOLDER_NAME="$TENANTS_DIR/$t"
      if docker ps --format '{{.Names}}' | grep -q "^web-$t$"; then
        log "Tenant web container for $t is already running. Skipping."
        continue
      fi
      mkdir -p "$FOLDER_NAME"
      cat > "$FOLDER_NAME/docker-compose.yml" <<EOF
version: '3.8'
services:
  web:
    image: nginx:alpine
    container_name: web-$t
    ports:
      - "8080:80"
    restart: always
EOF
    done
}

# === AUTO-GENERATE NGINX CONFIGS ===
function generate_nginx_configs() {
  log "Generating NGINX reverse proxy configs for all services and tenants..."
  mkdir -p "$REVERSE_PROXY_DIR/nginx/conf.d"
  # Main services
  cat > "$REVERSE_PROXY_DIR/nginx/conf.d/services.conf" <<EOF
server {
  listen 80;
  server_name $BASE_DOMAIN;
  location /homarr/ {
    proxy_pass http://homarr:7575/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
  location /cockpit/ {
    proxy_pass http://cockpit:9090/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
  location /portainer/ {
    proxy_pass http://portainer:9443/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
  location /dockge/ {
    proxy_pass http://dockge:5001/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
  location /pbx/ {
    proxy_pass http://pbx:8080/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF
  # Tenants
  for t in "${TENANT_DOMAINS[@]}"; do
    cat > "$REVERSE_PROXY_DIR/nginx/conf.d/tenant-$t.conf" <<TENANTCONF
server {
  listen 80;
  server_name $t;
  location / {
    proxy_pass http://tenant-$t:8080/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
TENANTCONF
  done
}

function show_connection_info() {
  echo -e "\n✅ Hardened and ready!"
  echo "Homarr:     http://$BASE_DOMAIN:7575"
  echo "Cockpit:    http://$BASE_DOMAIN:9090"
  echo "Portainer:  http://$BASE_DOMAIN:9443"
  echo "Dockge:     http://$BASE_DOMAIN:5001"
  echo "PBX:        http://$BASE_DOMAIN:5060"
  TENANTS_SAFE=("${TENANT_DOMAINS[@]:-}")
  if [[ ${#TENANTS_SAFE[@]} -gt 0 && -n "${TENANTS_SAFE[0]}" ]]; then
    echo -e "\nTenants (each in its own folder, access via port 8080):"
    for t in "${TENANTS_SAFE[@]}"; do
      echo "  Folder: $TENANTS_DIR/$t"
      echo "  Path:   $(realpath "$TENANTS_DIR/$t")"
      echo "  URL:    http://$BASE_DOMAIN:8080"
      echo
    done
  fi
  IP=$(curl -4 -s ifconfig.me)
  echo -e "\n🌐 Point your domain's A record(s) to: $IP"
  echo "Access services using the above ports. SSL and subdomain routing are disabled."
}


# === MAIN ===
# prompt_for_base_domain
# prompt_for_tenant_domains
install_docker_stack
setup_directories
deploy_reverse_proxy
deploy_homarr
# deploy_cockpit - 8.26 moved to harden.sh as part of inital server setup
deploy_portainer
deploy_dockge
deploy_pbx
configure_nginx_for_services
configure_homarr
deploy_tenants_example
show_connection_info
