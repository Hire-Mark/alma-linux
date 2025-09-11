#!/bin/bash
set -e

# --- CONFIG ---
REPO_URL="git@github.com:Hire-Mark/hello-world-tenant.git"
BRANCH="main"
BASE_DIR="/containers/tenants"
NGINX_CONF_DIR="/containers/reverse-proxy/nginx"

prompt_domain() {
  read -p "Enter the domain for this tenant (e.g., tnt1.hire-mark.com): " DOMAIN
  TENANT_NAME=$(echo "$DOMAIN")
  TENANT_DIR="$BASE_DIR/$TENANT_NAME"
}

clone_or_update_repo() {
  sudo mkdir -p "$TENANT_DIR"
  if [ ! -d "$TENANT_DIR/.git" ]; then
    sudo git clone -b "$BRANCH" "$REPO_URL" "$TENANT_DIR"
  else
    cd "$TENANT_DIR"
    sudo git fetch origin
    sudo git checkout "$BRANCH"
    sudo git pull
  fi
  cd "$TENANT_DIR"
}

build_and_start_containers() {
  sudo docker compose pull
  sudo docker compose up --build -d --force-recreate --remove-orphans
}

create_nginx_conf() {
  sudo mkdir -p "$NGINX_CONF_DIR"
  NGINX_CONF="$NGINX_CONF_DIR/$TENANT_NAME.conf"
  cat <<EOF | sudo tee "$NGINX_CONF"
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:36501; # Adjust port if needed
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
}

reload_nginx() {
  sudo systemctl reload nginx || sudo docker exec reverse-proxy nginx -s reload || true
}

issue_ssl_cert() {
  sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN || true
}

# --- MAIN ---
prompt_domain
clone_or_update_repo
build_and_start_containers
create_nginx_conf
reload_nginx
issue_ssl_cert
reload_nginx

echo "Deployment for tenant $TENANT_NAME complete!"