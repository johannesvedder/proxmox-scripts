#!/bin/bash

PUBLIC_IP=$(ip -4 addr show dev $PUBLIC_BRIDGE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)

# Create config file in $ROOT_DIR
CONFIG_FILE="$ROOT_DIR/config.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
  touch "$CONFIG_FILE"
  chmod +x "$CONFIG_FILE"
  echo "Config file created at $CONFIG_FILE"
else
  source "$CONFIG_FILE"
  echo "Config file loaded from $CONFIG_FILE"
fi

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
}