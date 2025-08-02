#!/bin/bash
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/johannesvedder/proxmox-scripts/refs/heads/main/main.sh)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ROOT_DIR

if ! command -v git >/dev/null 2>&1; then
    apt update
    apt install -y git
fi
if ! command -v bash >/dev/null 2>&1; then
    apt update
    apt install -y bash
fi

echo "🔧 Downloading Proxmox Scripts..."

# Check if menu.sh exists, if not clone the repository to /opt/proxmox-scripts
if [ ! -f "${ROOT_DIR}/menu.sh" ]; then
    git clone https://github.com/johannesvedder/proxmox-scripts /opt/proxmox-scripts
else
    echo "menu.sh already exists. Skipping clone."
fi

# Run menu.sh
bash "${ROOT_DIR}/menu.sh"

echo "✅ Setup complete."
