#!/bin/bash

read -p "Enter server IP: " IP
read -p "Enter SSH port: " PORT
read -p "Enter username: " USER
read -p "Enter alias name (leave blank to use '${USER}-${IP}'): " CUSTOM_ALIAS

# Use custom alias if provided, otherwise default to USER-IP
HOST_ALIAS="${CUSTOM_ALIAS:-${USER}-${IP}}"

# Check if entry already exists
if grep -q "Host $HOST_ALIAS" ~/.ssh/config; then
    echo "⚠️ SSH config already contains entry for '$HOST_ALIAS'. Skipping."
    exit 1
fi

cat <<EOF >> ~/.ssh/config

Host $HOST_ALIAS
    HostName $IP
    User $USER
    Port $PORT
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
EOF

echo "✅ SSH config updated. Try: ssh $HOST_ALIAS"


