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

  # Initialize config after first clone
  if [ -f "${ROOT_DIR}/helper/config_parser.sh" ]; then
    source "${ROOT_DIR}/helper/config_parser.sh"
    load_config
    # Set the initial commit SHA
    update_config "LATEST_COMMIT_SHA" "$REMOTE_COMMIT_SHA"
  fi
else
  # Load existing config first
  if [ -f "${ROOT_DIR}/helper/config_parser.sh" ]; then
    source "${ROOT_DIR}/helper/config_parser.sh"
    load_config
  fi

  # Get current commit SHA if not in config
  if [ -z "$LATEST_COMMIT_SHA" ]; then
    LATEST_COMMIT_SHA=$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || echo "")
  fi

  echo "🔍 Checking for updates..."
  echo "   Remote SHA: $REMOTE_COMMIT_SHA"
  echo "   Local SHA:  $LATEST_COMMIT_SHA"

  if [ "$REMOTE_COMMIT_SHA" != "$LATEST_COMMIT_SHA" ]; then
    echo "🔄 Updates found. Preserving config and updating..."

    # Fix: Correct backup filename with proper process ID
    CONFIG_BACKUP="/tmp/$(basename "$CONFIG_FILE").backup.$$"

    # Backup the entire config file if it exists
    if [ -f "$CONFIG_FILE" ]; then
      echo "📄 Backing up config file..."
      cp "$CONFIG_FILE" "$CONFIG_BACKUP"
      echo "   Config backed up to: $CONFIG_BACKUP"
    else
      echo "⚠️  No config file found at $CONFIG_FILE"
    fi

    # Clean the directory
    echo "🧹 Cleaning directory..."
    find "$ROOT_DIR" -mindepth 1 -delete

    # Re-clone
    echo "📥 Fetching latest code..."
    git -C "$ROOT_DIR" init
    git -C "$ROOT_DIR" remote add origin "https://github.com/$GITHUB_USER/$GITHUB_REPO" 2>/dev/null || true
    git -C "$ROOT_DIR" fetch origin "$BRANCH"
    git -C "$ROOT_DIR" reset --hard "origin/$BRANCH"

    # Restore config BEFORE calling update_config
    if [ -f "$CONFIG_BACKUP" ]; then
      echo "📄 Restoring config file..."
      # Recreate parent directory structure if needed
      mkdir -p "$(dirname "$CONFIG_FILE")"
      cp "$CONFIG_BACKUP" "$CONFIG_FILE"
      rm -f "$CONFIG_BACKUP"
      echo "   Config restored"

      # Re-source the config parser and load the restored config
      if [ -f "${ROOT_DIR}/helper/config_parser.sh" ]; then
        source "${ROOT_DIR}/helper/config_parser.sh"
        load_config  # This will reload all the preserved config values
      fi
    fi

    # Now update the commit SHA (this will preserve other config values)
    update_config "LATEST_COMMIT_SHA" "$REMOTE_COMMIT_SHA"

    echo "✅ Update complete"
  else
    echo "✅ Already up to date"
  fi
fi

export ROOT_DIR

source "${ROOT_DIR}/helper/network.sh"
source "${ROOT_DIR}/proxmox/container_tasks.sh"
source "${ROOT_DIR}/tools/install_docker.sh"

# Run menu.sh
bash "${ROOT_DIR}/menu.sh"

echo "✅ Setup complete."
