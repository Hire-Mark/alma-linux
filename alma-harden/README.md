# AlmaLinux Hardening Script

This script sets up a secure AlmaLinux VM with:

- New admin user
- Randomized SSH port
- Password login enabled
- Root login disabled

## Usage

Run this one-liner on a fresh VM:

```bash
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-harden/main/harden.sh)


