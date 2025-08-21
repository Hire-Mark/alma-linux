#!/bin/bash

set -e

echo "🔑 Remote-SSH setup for existing user"

read -p "Enter existing admin username: " USER
read -p "Paste your public SSH key: " PUBKEY

mkdir -p /home/"$USER"/.ssh
echo "$PUBKEY" > /home/"$USER"/.ssh/authorized_keys
chmod 600 /home/"$USER"/.ssh/authorized_keys
chown -R "$USER":"$USER" /home/"$USER"/.ssh

# Disable password login now (optional)
sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
systemctl restart sshd

echo "✅ SSH key installed for $USER"
