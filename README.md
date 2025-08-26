# 🛡️ AlmaLinux Server Bootstrap Toolkit #

This repo contains modular scripts for securely provisioning and accessing AlmaLinux VPS instances. Each module is designed to be run remotely via a single command, making onboarding fast, repeatable, and secure.


## 📁 Repo Structure

alma-linux/<br>
├── alma-harden/ # Initial OS hardening with password login<br>
│ └── harden.sh<br>
│ └── multi-tenant-container-stack-install.sh<br>
├── alma-harden-ssh/ # SSH key setup and password login disablement<br>
│ ├── harden-ssh.sh<br>
│ └── README.md<br>
├── alma-ssh-alias/ # Local SSH alias creation for easy access<br>
│ ├── setup-alias.sh<br>
│ └── README.md<br>


## 🚀 One-Liner Remote Installs

## 🔧 Initial Hardening (Run as root on fresh AlmaLinux VPS)

Creates a new admin user, randomizes SSH port, disables root login, and enables password login.

```
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-linux/main/alma-harden/harden.sh)
```

After running, you'll see connection info like:

```
ssh -p <random-port> <admin-user>@<server-ip>
```
## 🔐 SSH Key Setup (Run after hardening, logged in as admin user)
Installs your public SSH key and disables password login for secure access.

```
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-linux/main/alma-harden-ssh/harden-ssh.sh)
```

Make sure you've generated your SSH key locally first. See alma-harden-ssh/README.md for instructions.

## 🧭 SSH Alias Setup (Run locally on your dev machine)
Creates a shortcut in your ~/.ssh/config so you can connect using a simple alias like ssh hire-mark.

```
bash <(curl -s https://raw.githubusercontent.com/hire-mark/alma-linux/main/alma-ssh-alias/setup-alias.sh)
```
You'll be prompted for:
```
    Server IP
    SSH port
    Username
    Optional alias name
```

🧠 Recommended Workflow
- Provision a fresh AlmaLinux VPS<br>
- Run the harden.sh script remotely as root<br>
- SSH in using password and randomized port<br>
* Optional: Run the harden-ssh.sh script to install your public key and disable password login<br>
* Optional: Run the setup-alias.sh script locally to create a shortcut for future access<br>

📌 Notes
- All scripts are modular and safe to run independently<br>
- No secrets or sensitive data are stored in this repo<br>
- You can customize identity files, alias formats, and SSH options as needed<br>

🔗 Learn More
Created by Mark Hart — technical architect focused on secure, scalable infrastructure automation.<br>