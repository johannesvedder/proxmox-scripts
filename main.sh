#!/bin/bash
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/johannesvedder/proxmox-scripts/refs/heads/main/main.sh)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v git >/dev/null 2>&1; then
    apt update
    apt install -y git
fi
if ! command -v bash >/dev/null 2>&1; then
    apt update
    apt install -y bash
fi

# Check if menu.sh exists, if not clone the repository to /opt/proxmox-scripts
if [ ! -f "${ROOT_DIR}/menu.sh" ]; then
    echo "🔧 Downloading Proxmox Scripts..."
    git clone https://github.com/johannesvedder/proxmox-scripts /opt/proxmox-scripts
    ROOT_DIR="/opt/proxmox-scripts"
    echo "✅ Proxmox Scripts downloaded to ${ROOT_DIR}"
else
    echo "menu.sh already exists. Skipping clone."
fi

source "${ROOT_DIR}/helper/utils.sh"
source "${ROOT_DIR}/proxmox/container_tasks.sh"

# Run menu.sh
source "${ROOT_DIR}/menu.sh"

echo "✅ Setup complete."
