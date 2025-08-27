#!/bin/bash

set -euo pipefail

# === CONFIGURATION ===
# Default base domain
DEFAULT_BASE_DOMAIN="vps.hire-mark.com"

# Prompt for base domain at runtime
function prompt_for_base_domain() {
  read -p "Please enter the primary domain to configure for this server (e.g. example.com) [default: $DEFAULT_BASE_DOMAIN]: " INPUT_DOMAIN
  if [[ -z "$INPUT_DOMAIN" ]]; then
    BASE_DOMAIN="$DEFAULT_BASE_DOMAIN"
  else
    BASE_DOMAIN="$INPUT_DOMAIN"
  fi
  log "Using base domain: $BASE_DOMAIN"
}
# Default tenant domains
DEFAULT_TENANT_DOMAINS=(lab.hire-mark.com tnt.h3webelements.com beta.h3webelements.com)

# Prompt for tenant domains at runtime
function prompt_for_tenant_domains() {
  read -p "Enter tenant domains (comma-separated, or leave blank for default: ${DEFAULT_TENANT_DOMAINS[*]}): " DOMAINS_INPUT
  if [[ -z "$DOMAINS_INPUT" ]]; then
    TENANT_DOMAINS=("${DEFAULT_TENANT_DOMAINS[@]}")
  else
    IFS=',' read -ra TENANT_DOMAINS <<< "$DOMAINS_INPUT"
    # Trim whitespace
    for i in "${!TENANT_DOMAINS[@]}"; do
      TENANT_DOMAINS[$i]="$(echo ${TENANT_DOMAINS[$i]} | xargs)"
    done
  fi
}
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
    log "Deploying NGINX reverse proxy with Certbot..."
    mkdir -p "$REVERSE_PROXY_DIR/nginx/conf.d"
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
    log "Deploying Portainer..."
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
      - ./data:/data
    restart: always
EOF
}

function deploy_dockge() {
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
    log "Deploying PBX (placeholder)..."
    cat > "$PBX_DIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  pbx:
    image: placeholder/pbx:latest
    container_name: pbx
    ports:
      - "5060:5060"
    restart: always
EOF
}

function configure_nginx_for_services() {
    log "Configuring NGINX for service routing..."
  cat > "$NGINX_CONF_DIR/homarr.conf" <<EOF
server {
  listen 80;
  server_name $BASE_DOMAIN;
  location / {
    proxy_pass http://homarr:7575;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF
#  cat > "$NGINX_CONF_DIR/cockpit.conf" <<EOF
#server {
# listen 80;
#  server_name cockpit.$BASE_DOMAIN;
#  location / {
#    proxy_pass http://cockpit:9090;
#    proxy_set_header Host \$host;
#    proxy_set_header X-Real-IP \$remote_addr;
#  }
#}
#EOF
}

function configure_homarr() {
    log "Configuring Homarr dashboard for service links..."
    mkdir -p "$HOMARR_DIR/data"
    cat > "$HOMARR_DIR/data/services.json" <<EOF
[
  { "name": "Cockpit", "url": "https://cockpit.$BASE_DOMAIN" },
  { "name": "Homarr", "url": "https://$BASE_DOMAIN" },
  { "name": "Portainer", "url": "https://$BASE_DOMAIN:9443" },
  { "name": "Dockge", "url": "https://$BASE_DOMAIN:5001" },
  { "name": "PBX", "url": "https://$BASE_DOMAIN:5060" }
]
EOF
}

function deploy_tenants_example() {
    log "Creating example tenant folders and configs..."
    for t in "${TENANT_DOMAINS[@]}"; do
      mkdir -p "$TENANTS_DIR/$t"
      cat > "$TENANTS_DIR/$t/docker-compose.yml" <<EOF
version: '3.8'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
    restart: always
EOF
      cat > "$TENANTS_DIR/$t/nginx.conf" <<EOF
server {
  listen 80;
  server_name $t;
  location / {
    proxy_pass http://web:80;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EOF
    done
}

function show_connection_info() {
  echo -e "\n✅ Hardened and ready!"
  echo "Homarr: https://$BASE_DOMAIN"
  echo "Cockpit: https://$BASE_DOMAIN:9090"
  echo "Portainer: https://$BASE_DOMAIN:9443"
  echo "Dockge: https://$BASE_DOMAIN:5001"
  echo "PBX: https://$BASE_DOMAIN:5060"
  IP=$(curl -4 -s ifconfig.me)
  echo -e "\n🌐 Point your domain's A record to: $IP"
  echo "Then use Certbot to generate SSL certificates for your domains."
}

deploy_portainer
deploy_dockge
deploy_pbx
configure_nginx_for_services
configure_homarr
deploy_tenants_example
show_connection_info
# === MAIN ===
install_docker_stack
setup_directories
prompt_for_base_domain
prompt_for_tenant_domains
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
