#!/bin/bash

set -e

echo "🔐 Running AlmaLinux hardening script by Mark Hart"
echo "Learn more at www.hire-mark.com"

# Prompt for new admin username
read -p "Enter new admin username: " NEW_USER

# Generate random SSH port between 20000–65000
SSH_PORT=$(shuf -i 20000-65000 -n 1)

# Create user and add to wheel group
useradd -m -s /bin/bash "$NEW_USER"
passwd "$NEW_USER"  # Enable password login and prompt to set password
usermod -aG wheel "$NEW_USER"

# Setup SSH directory (optional, no key yet)
mkdir -p /home/"$NEW_USER"/.ssh
chmod 700 /home/"$NEW_USER"/.ssh
chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh

# Harden SSH config (but keep password auth enabled)
sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart sshd

# Output connection info
IP=$(curl -s ifconfig.me)
echo -e "\n✅ Hardened and ready for password login!"
echo "Connect using:"
echo "ssh -p $SSH_PORT $NEW_USER@$IP"
