#!/bin/bash

set -e

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="nginx-proxy-manager"
export CORES="2"
export MEMORY="1024"
export SWAP="512"
export DISK="4"

# === Run container creation ===
source "${ROOT_DIR}/proxmox/container.sh"

# === Run container setup ===
pct exec "$CTID" -- bash -c "source '${APP_DIR}'/container.sh"
