#!/bin/bash

set -euo pipefail

echo "🔐 Running AlmaLinux hardening script by Mark Hart"
echo "Learn more at www.hire-mark.com"

# === CONFIGURATION ===
SSH_PORT_MIN=20000
SSH_PORT_MAX=65000
COPILOT_PORT=9090
NGINX_CONF_DIR="/etc/nginx/conf.d"

# === FUNCTIONS ===
function log() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

function fail() {
    echo -e "\e[31m[ERROR]\e[0m $1"
    exit 1
}

function prompt_for_ssh_port() {
    echo "Choose a custom SSH port between $SSH_PORT_MIN and $SSH_PORT_MAX:"
    read -p "SSH Port: " SSH_PORT
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < SSH_PORT_MIN || SSH_PORT > SSH_PORT_MAX )); then
        fail "Invalid port. Must be between $SSH_PORT_MIN and $SSH_PORT_MAX."
    fi
}

function setup_user() {
    read -p "Enter new admin username: " NEW_USER
    useradd -m -s /bin/bash "$NEW_USER"
    passwd "$NEW_USER"
    usermod -aG wheel "$NEW_USER"
    mkdir -p /home/"$NEW_USER"/.ssh
    chmod 700 /home/"$NEW_USER"/.ssh
    chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
}

function harden_ssh() {
    sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
    systemctl restart sshd
}

function setup_firewall() {
    log "Installing firewalld..."
    dnf install -y firewalld
    systemctl enable --now firewalld

    log "Configuring firewall rules..."
    firewall-cmd --permanent --add-port="${SSH_PORT}/tcp"
    firewall-cmd --permanent --add-port="${COPILOT_PORT}/tcp"
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
}

function install_cockpit() {
    log "Installing Cockpit..."
    dnf install -y cockpit
    systemctl enable --now cockpit.socket
}

function install_certbot_nginx() {
    log "Installing Let's Encrypt certbot for NGINX..."
    dnf install -y epel-release
    dnf install -y certbot python3-certbot-nginx
    log "Certbot installed. You can now run:"
    echo "  sudo certbot --nginx"
}

function install_docker_stack() {
    log "Installing Docker and Docker Compose..."
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    log "Docker installed. You can now run containers and compose stacks."
}

function install_nginx_proxy() {
    log "Installing NGINX reverse proxy..."
    dnf install -y nginx
    systemctl enable --now nginx
}

function setup_container_stacks() {
    log "Creating Docker Compose stacks for two domains..."

    mkdir -p /opt/stack1 /opt/stack2

    cat > /opt/stack1/docker-compose.yml <<EOF
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8081:80"
    restart: always
EOF

    cat > /opt/stack2/docker-compose.yml <<EOF
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8082:80"
    restart: always
EOF

    docker compose -f /opt/stack1/docker-compose.yml up -d
    docker compose -f /opt/stack2/docker-compose.yml up -d

    log "Stacks running: stack1 on port 8081, stack2 on port 8082"
}

function configure_nginx_domains() {
    read -p "Enter domain for stack1 (e.g. domain1.com): " DOMAIN1
    read -p "Enter domain for stack2 (e.g. domain2.com): " DOMAIN2

    cat > "$NGINX_CONF_DIR/$DOMAIN1.conf" <<EOF
server {
    listen 80;
    server_name $DOMAIN1;

    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    cat > "$NGINX_CONF_DIR/$DOMAIN2.conf" <<EOF
server {
    listen 80;
    server_name $DOMAIN2;

    location / {
        proxy_pass http://localhost:8082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

    systemctl restart nginx
    log "NGINX configs created for $DOMAIN1 and $DOMAIN2. Ready for Certbot."
}

function show_connection_info() {
    IP=$(curl -s ifconfig.me)
    echo -e "\n✅ Hardened and ready for password login!"
    echo "Connect using:"
    echo "ssh -p $SSH_PORT $NEW_USER@$IP"
    echo "Cockpit GUI available at: https://$IP:$COPILOT_PORT"
    echo -e "\n🌐 Point your domain's A record to: $IP"
    echo "Then run:"
    echo "  sudo certbot --nginx -d yourdomain.com -d otherdomain.com"
}

# === MAIN ===
prompt_for_ssh_port
setup_user
harden_ssh
setup_firewall
install_cockpit
install_certbot_nginx
install_docker_stack
install_nginx_proxy
setup_container_stacks
configure_nginx_domains
show_connection_info
