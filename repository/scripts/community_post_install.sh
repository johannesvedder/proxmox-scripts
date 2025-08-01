#!/bin/bash

echo "⚙️ Running Proxmox community post-install script..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
