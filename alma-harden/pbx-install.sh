# create script to install and configure FreePBX as a container on a running Docker host
# update the current reverse proxy configuration for correct routing
#!/bin/bash

#Functions
#Deploy docker container
function deploy_pbx_container() {
  if docker ps --format '{{.Names}}' | grep -q '^pbx$'; then
    log "PBX is already running. Skipping."
    return
  fi
  log "Deploying PBX..."
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

#Deploy NGINX configuration
function deploy_pbx_nginx_config() {
  if [ ! -d "$NGINX_CONF_DIR" ]; then
    mkdir -p "$NGINX_CONF_DIR"
  fi
  cat > "$NGINX_CONF_DIR/pbx.conf" <<EOF
server {
    listen 80;
    server_name pbx.$BASE_DOMAIN;

    location / {
        proxy_pass http://pbx:5060;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
  echo "[INFO] PBX NGINX config created at $NGINX_CONF_DIR/pbx.conf"
}

#Deploy PBX
function deploy_pbx() {
  deploy_pbx_container
  deploy_pbx_nginx_config
}

#Main script
deploy_pbx
