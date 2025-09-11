#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
BASE_DOMAIN="lab.hire-mark.com"
TENANT_DOMAIN1=""
TENANT_DOMAIN2=""
TENANT_DOMAINS=("$BASE_DOMAIN")
CONTAINERS_DIR="/containers"
REVERSE_PROXY_DIR="$CONTAINERS_DIR/reverse-proxy"
HOMARR_DIR="$CONTAINERS_DIR/homarr"
COCKPIT_DIR="$CONTAINERS_DIR/cockpit"
PORTAINER_DIR="$CONTAINERS_DIR/portainer"
DOCKGE_DIR="$CONTAINERS_DIR/dockge"
#PBX_DIR="$CONTAINERS_DIR/pbx"
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
    mkdir -p "$REVERSE_PROXY_DIR" "$HOMARR_DIR" "$COCKPIT_DIR" "$PORTAINER_DIR" "$DOCKGE_DIR" "$TENANTS_DIR"
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
ervices:
  nginx:
    image: nginx:alpine
    container_name: reverse-proxy
    networks:
      - appnet
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
    networks:
      - appnet
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    entrypoint: ""
    command: "tail -f /dev/null"
networks:
  appnet:
    driver: bridge
EOF
}

function deploy_homarr() {
  if docker ps --format '{{.Names}}' | grep -q '^homarr$'; then
    log "Homarr is already running. Skipping."
    return
  fi
  log "Deploying Homarr..."
  cat > "$HOMARR_DIR/docker-compose.yml" <<EOF

services:
  homarr:
    image: ghcr.io/homarr-labs/homarr:latest
    container_name: homarr
    ports:
      - "7575:7575"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./data:/app/data/configs
    environment:
      - SECRET_ENCRYPTION_KEY=3d92814d556976ce9114147fe7e77ac670d87dfd756a0f53c4788c48bf9daaa2
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
#version: '3.8'
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
#version: '3.8'
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
#version: '3.8'
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
      #echo "  { \"name\": \"PBX\",       \"url\": \"http://$BASE_DOMAIN:5060\" }"
      TENANTS_SAFE=("${TENANT_DOMAINS[@]:-}")
      if [[ ${#TENANTS_SAFE[@]} -gt 0 && -n "${TENANTS_SAFE[0]}" ]]; then
  local port=36501
        for t in "${TENANTS_SAFE[@]}"; do
          echo ",  { \"name\": \"Tenant: $t\", \"url\": \"http://$BASE_DOMAIN:${port}\" }"
          ((port++))
        done
      fi
      echo "]"
    } > "$HOMARR_DIR/data/services.json"
}

function deploy_tenants_example() {
    log "Creating example tenant folders and configs..."
  local port=9000
    for t in "${TENANT_DOMAINS[@]}"; do
      FOLDER_NAME="$TENANTS_DIR/$t"
      if docker ps --format '{{.Names}}' | grep -q "^web-$t$"; then
        log "Tenant web container for $t is already running. Skipping."
        ((port++))
        continue
      fi
      mkdir -p "$FOLDER_NAME"
      cat > "$FOLDER_NAME/docker-compose.yml" <<EOF
#version: '3.8'
services:
  web:
    image: nginx:alpine
    container_name: web-$t
    networks:
      - appnet
    ports:
      - "${port}:80"
    restart: always
networks:
  appnet:
    driver: bridge
EOF
      ((port++))
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
  listen 443 ssl;
  server_name $BASE_DOMAIN;

  ssl_certificate /etc/letsencrypt/live/$BASE_DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$BASE_DOMAIN/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;

  # Route / to the default tenant container using Docker service name
  location / {
    proxy_pass http://web-$BASE_DOMAIN:80/;
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
  listen 443 ssl;
  server_name $t;

  ssl_certificate /etc/letsencrypt/live/$t/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$t/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;

  location / {
    proxy_pass http://web-$t:80/;
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
  #echo "PBX:        http://$BASE_DOMAIN:5060"
  TENANTS_SAFE=("${TENANT_DOMAINS[@]:-}")
  if [[ ${#TENANTS_SAFE[@]} -gt 0 && -n "${TENANTS_SAFE[0]}" ]]; then
    echo -e "\nTenants (each in its own folder, access via port 8080):"
    for t in "${TENANTS_SAFE[@]}"; do
      echo "  Folder: $TENANTS_DIR/$t"
      echo "  Path:   $(realpath "$TENANTS_DIR/$t")"
      echo "  URL:    http://$BASE_DOMAIN:36501"
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
#deploy_pbx
#configure_nginx_for_services
configure_homarr
#deploy_tenants_example
show_connection_info
