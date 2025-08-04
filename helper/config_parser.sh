#!/bin/bash

# Create config file in $ROOT_DIR
CONFIG_FILE="$ROOT_DIR/config.sh"
export CONFIG_FILE
if [[ ! -f "$CONFIG_FILE" ]]; then
  touch "$CONFIG_FILE"
  chmod +x "$CONFIG_FILE"
  echo "Config file created at $CONFIG_FILE"
else
  # Export all variables from config.sh
  set -a
  source "$CONFIG_FILE"
  set +a
  echo "Config file loaded from $CONFIG_FILE"
fi

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

#if [[ -z "$INTERNAL_SUBNET" ]]; then
#  INTERNAL_SUBNET=$(ip -o -f inet addr show vmbr0 | awk '{print $4}' | head -n1)
#  export INTERNAL_SUBNET
#fi

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

#request_config() {
#  local key="$1"
#  local prompt="$2"
#  local default_value="$3"

  # Check if the key already exists
#  if grep -q "^$key=" "$CONFIG_FILE"; then
    # If it exists, read the value from the config file
#    value=$(grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"')
#    echo "Current value for $key: $value"
#  else
    # If it doesn't exist, prompt the user for input
#    read -rp "$prompt [$default_value]: " value
#    value=${value:-$default_value}
#  fi

  # Update the config file with the new value
#  update_config "$key" "$value"
#}
#export -f request_config
