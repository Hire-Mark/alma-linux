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
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden-full-install.sh)
```

**Combined one-liner:**
```bash
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden.sh) && bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden-full-install.sh)
```


