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
    echo "Setting up firewall..."
    log "Installing firewalld..."
    dnf install -y firewalld
    systemctl enable --now firewalld

    echo "Configuring firewall rules..."
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
    echo "Setting up Let's Encrypt certbot for NGINX..."
    log "Installing Let's Encrypt certbot for NGINX..."
    dnf install -y epel-release
    dnf install -y certbot python3-certbot-nginx
    log "Certbot installed. You can now run:"
    echo "  sudo certbot --nginx"
}

function install_docker_stack() {
    echo "Setting up Docker and Docker Compose..."
    log "Installing Docker and Docker Compose..."
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    echo "Docker installed. You can now run Docker Compose commands."
    log "Docker installed. You can now run containers and compose stacks."
}

function install_nginx_proxy() {
    echo "Setting up NGINX reverse proxy..."
    log "Installing NGINX reverse proxy..."
    dnf install -y nginx
    systemctl enable --now nginx

    log "Creating base domain routing config..."
    cat > "$NGINX_CONF_DIR"/default.conf <<EOF
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
    echo "NGINX is ready for domain-based routing. Replace 'example.com' with your domain and restart NGINX:"
    log "NGINX is ready for domain-based routing. Replace 'example.com' with your domain and restart NGINX:"
    echo "  sudo systemctl restart nginx"
}

function show_connection_info() {
    IP=$(curl -4 -s ifconfig.me)
    echo -e "\n✅ Hardened and ready for password login!"
    echo "Connect using:"
    echo "ssh -p $SSH_PORT $NEW_USER@$IP"
    echo "Cockpit GUI available at: https://$IP:$COPILOT_PORT"
    echo -e "\n🌐 Point your domain's A record to: $IP"
}

# === MAIN ===
prompt_for_ssh_port
setup_user
harden_ssh
setup_firewall
install_cockpit
# install_certbot_nginx
# install_docker_stack
# install_nginx_proxy
show_connection_info
