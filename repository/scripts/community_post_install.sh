#!/bin/bash

echo "⚙️ Running Proxmox community post-install script..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"

read -rp "Configure thin pool and check status? [y/N] " yn
if [[ $yn =~ ^[Yy]$ ]]; then
  # Set thin pool autoextend threshold and increment
  lvchange --activation/thin_pool_autoextend_threshold 80 pve/data
  lvchange --activation/thin_pool_autoextend_percent 20 pve/data

  # Add metadata space if needed
  lvextend --poolmetadatasize +500M pve/data

  # Check status
  lvs -a -o+seg_monitor
  vgs pve
fi
