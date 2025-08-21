# 🔐 SSH Key Setup for Hardened AlmaLinux VPS

This script installs your public SSH key for an existing admin user and disables password login for secure remote access.

---

## ⚙️ Step 1: Generate Your SSH Key Locally

Before running `harden-ssh.sh` on your server, you need to create an SSH key pair on your local machine.

### ✅ Linux / macOS / Git Bash (Windows)

1. **Open your terminal and check for existing keys**:
   ```bash
   ls ~/.ssh/id_*.pub

2. If no key exists, generate one:

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    Press Enter to accept the default location (~/.ssh/id_ed25519)
    Optionally set a passphrase

3. Display your public key:

    ```bash
    cat ~/.ssh/id_ed25519.pub
    
    Copy the full key to your clipboard:
        macOS: pbcopy < ~/.ssh/id_ed25519.pub
        Linux: xclip -sel clip < ~/.ssh/id_ed25519.pub
        Windows (Git Bash): Right-click to copy after running cat


run the script
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-linux/main/alma-harden-ssh/harden-ssh.sh)


