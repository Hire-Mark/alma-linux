# AlmaLinux Server Setup


## AlmaLinux Hardening & Full Install Scripts

This repo provides two scripts:

- `harden.sh`: OS hardening (user, SSH, firewall, etc.)
- `multi-tenant-container-stack-install.sh`: Installs and configures containers, reverse proxy, and tenant structure

## Usage

**1. Harden your AlmaLinux server (run first):**
```bash
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden.sh)
```

**2. Install and configure containers (run after hardening):**
```bash
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/default-containers.sh)
```

**Combined one-liner:**
```bash
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden.sh) && bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden-full-install.sh)
```

## Install script to build and launch the containers
```
install container lauch script
sudo mkdir -p /opt/startup
sudo curl -sSL https://raw.githubusercontent.com/hire-mark/alma-linux/main/alma-harden/containers-up.sh -o /opt/startup/containers-up.sh
sudo chmod +x /opt/startup/containers-up.sh

```
**Run the script**
```
sudo /opt/startup/containers-up.sh
```
## Docker Networking & Service Name Proxying

All containers are deployed on a shared Docker network (`appnet`) for secure, service-name-based communication. NGINX proxy configs use Docker service names (not localhost or static IPs) for routing requests to tenant apps and services.

Example NGINX config:
```nginx
location / {
	proxy_pass http://web-<tenant>:80;
}
```

This ensures reliable networking and easy scaling for multi-tenant deployments.
