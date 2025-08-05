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

if ! command -v jq >/dev/null 2>&1; then
    apt update
    apt install -y jq
fi

GITHUB_USER="johannesvedder"
GITHUB_REPO="proxmox-scripts"
BRANCH="main"
ROOT_DIR="/opt/${GITHUB_REPO}"
CONFIG_FILE="config.sh"
echo "test"

# Get latest remote commit SHA
REMOTE_COMMIT_SHA=$(curl -s "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/commits/$BRANCH" | jq -r '.sha')
if [ -z "$REMOTE_COMMIT_SHA" ] || [ "$REMOTE_COMMIT_SHA" = "null" ]; then
  echo "❌ Failed to get latest commit SHA. Aborting."
  exit 1
fi

if [ ! -f "${ROOT_DIR}/main.sh" ]; then
  echo "🔧 Cloning Proxmox Scripts for the first time..."
  git clone --branch "$BRANCH" "https://github.com/$GITHUB_USER/$GITHUB_REPO" "$ROOT_DIR"
  echo "✅ Cloned to $ROOT_DIR"
  if [ -f "${ROOT_DIR}/helper/config_parser.sh" ]; then
    source "${ROOT_DIR}/helper/config_parser.sh"
    load_config
  fi
else
  # Load saved SHA (fallback if not saved in config)
  if [ -f "${ROOT_DIR}/helper/config_parser.sh" ]; then
    source "${ROOT_DIR}/helper/config_parser.sh"
    load_config
  fi

  if [ -z "$LATEST_COMMIT_SHA" ]; then
    LATEST_COMMIT_SHA=$(git -C "$ROOT_DIR" rev-parse HEAD)
  fi

  if [ "$REMOTE_COMMIT_SHA" != "$LATEST_COMMIT_SHA" ]; then
    # Method 1: Backup config, remove all, restore config
    CONFIG_BACKUP="/tmp/$(basename "$CONFIG_FILE").backup.$"
    if [ -f "$ROOT_DIR/$CONFIG_FILE" ]; then
      cp "$ROOT_DIR/$CONFIG_FILE" "$CONFIG_BACKUP"
    fi

    # Remove everything in ROOT_DIR except the directory itself
    find "$ROOT_DIR" -mindepth 1 -delete

    # Restore config
    if [ -f "$CONFIG_BACKUP" ]; then
      # Recreate parent directory structure if needed
      mkdir -p "$(dirname "$ROOT_DIR/$CONFIG_FILE")"
      mv "$CONFIG_BACKUP" "$ROOT_DIR/$CONFIG_FILE"
    fi

    # Method 2: Alternative - exclude parent directories of config file
    # CONFIG_DIR=$(dirname "$ROOT_DIR/$CONFIG_FILE")
    # find "$ROOT_DIR" -mindepth 1 ! -path "$ROOT_DIR/$CONFIG_FILE" ! -path "$CONFIG_DIR" ! -path "$CONFIG_DIR/*" -delete

    # Re-clone or pull
    git -C "$ROOT_DIR" init
    git -C "$ROOT_DIR" remote add origin "https://github.com/$GITHUB_USER/$GITHUB_REPO" 2>/dev/null || true
    git -C "$ROOT_DIR" fetch origin "$BRANCH"
    git -C "$ROOT_DIR" reset --hard "origin/$BRANCH"

    update_config "LATEST_COMMIT_SHA" "$REMOTE_COMMIT_SHA"
  fi
fi

export ROOT_DIR

source "${ROOT_DIR}/helper/network.sh"
source "${ROOT_DIR}/proxmox/container_tasks.sh"
source "${ROOT_DIR}/tools/install_docker.sh"

#while true; do
#  read -rp "Are you sure you want to run the setup? [y/n] " yn < /dev/tty
#  case $yn in
#    [Yy]*) break ;;
#    [Nn]*) echo "❌ Setup aborted."; exit 0 ;;
#    *) echo "Please answer yes or no." ;;
#  esac
#done

# Run menu.sh
bash "${ROOT_DIR}/menu.sh"

echo "✅ Setup complete!"
