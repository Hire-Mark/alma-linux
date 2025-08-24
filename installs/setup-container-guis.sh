#!/bin/bash

set -euo pipefail

# === Configurable Flags ===
INSTALL_DOCKER=true
INSTALL_PORTAINER=true
INSTALL_DOCKGE=true

# === Parse Flags ===
for arg in "$@"; do
  case $arg in
    --no-docker) INSTALL_DOCKER=false ;;
    --no-portainer) INSTALL_PORTAINER=false ;;
    --no-dockge) INSTALL_DOCKGE=false ;;
  esac
done

# === Helper Functions ===
function log() {
  echo -e "\n🔹 $1"
}

function ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root"
    exit 1
  fi
}

function install_docker() {
  log "Installing Docker..."
  if ! command -v docker &>/dev/null; then
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
    log "✅ Docker installed and running"
  else
    log "✅ Docker already installed"
  fi
}

function setup_firewall() {
  log "Configuring firewall..."
  systemctl enable --now firewalld
  firewall-cmd --permanent --add-port=9000/tcp   # Portainer
  firewall-cmd --permanent --add-port=8000/tcp   # Portainer Edge
  firewall-cmd --permanent --add-port=5001/tcp   # Dockge
  firewall-cmd --reload
  log "✅ Firewall rules applied"
}

function install_portainer() {
  log "Deploying Portainer..."
  docker volume create portainer_data
  docker run -d \
    --name portainer \
    --restart=always \
    -p 9000:9000 \
    -p 8000:8000 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce
  log "✅ Portainer running at: http://$(curl -s ifconfig.me):9000"
}

function install_dockge() {
  log "Deploying Dockge..."
  git clone https://github.com/louislam/dockge.git /opt/dockge
  cd /opt/dockge
  docker compose up -d
  log "✅ Dockge running at: http://$(curl -s ifconfig.me):5001"
}

function harden_server() {
  log "Applying basic server hardening..."

  # Disable root SSH login
  sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  systemctl restart sshd

  # Enable automatic updates
  dnf -y install dnf-automatic
  systemctl enable --now dnf-automatic.timer

  # Install fail2ban
  dnf -y install epel-release
  dnf -y install fail2ban
  systemctl enable --now fail2ban

  log "✅ Basic hardening applied: SSH lockdown, auto updates, fail2ban"
}

function show_summary() {
  echo -e "\n🎉 Setup complete!"
  echo "Portainer: http://$(curl -s ifconfig.me):9000"
  echo "Dockge:    http://$(curl -s ifconfig.me):5001"
}

# === Main Execution ===
ensure_root
$INSTALL_DOCKER && install_docker
setup_firewall
$INSTALL_PORTAINER && install_portainer
$INSTALL_DOCKGE && install_dockge
harden_server
show_summary
