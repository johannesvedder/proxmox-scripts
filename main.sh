#!/bin/bash

echo "🔧 Downloading Proxmox Scripts..."

# Clone the repository to /opt/proxmox-scripts
if [ ! -d "/opt/proxmox-scripts" ]; then
    git clone https://github.com/johannesvedder/proxmox-scripts /opt/proxmox-scripts
else
    echo "/opt/proxmox-scripts already exists. Skipping clone."
fi

# Run menu.sh from /opt/proxmox-scripts
if [ -f "/opt/proxmox-scripts/menu.sh" ]; then
    bash /opt/proxmox-scripts/menu.sh
else
    echo "menu.sh not found in /opt/proxmox-scripts."
fi

echo "✅ Setup complete."
