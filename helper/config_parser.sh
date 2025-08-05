#!/bin/bash

load_config() {
  # Create config file in $ROOT_DIR
  CONFIG_FILE="$ROOT_DIR/config.sh"
  export CONFIG_FILE

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating new config file at $CONFIG_FILE"
    touch "$CONFIG_FILE"
    chmod +x "$CONFIG_FILE"
  else
    echo "Loading existing config file from $CONFIG_FILE"
    echo "Config file size: $(wc -l < "$CONFIG_FILE") lines"
    # Export all variables from config.sh
    set -a
    source "$CONFIG_FILE"
    set +a
  fi
}
export -f load_config

# Set default values for variables if not already set

# PUBLIC_IP=$(ip -4 addr show dev $PUBLIC_BRIDGE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
PUBLIC_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
export PUBLIC_IP

GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
export GATEWAY

if [[ -z "$PUBLIC_BRIDGE" ]]; then
  PUBLIC_BRIDGE="vmbr0" # WAN
  export PUBLIC_BRIDGE
fi

# Improved update_config with better error handling
update_config() {
  local key="$1"
  local value="$2"

  # Check if the key already exists
  if grep -q "^$key=" "$CONFIG_FILE"; then
    # Update the existing key
    sed -i "s|^$key=.*|$key=\"$value\"|" "$CONFIG_FILE"
  else
    # Add the new key
    echo "$key=\"$value\"" >> "$CONFIG_FILE"
  fi

  # Export the updated variable
  export "$key"="$value"
}
export -f update_config
