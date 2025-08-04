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
create_container

# Ask user if they want to forward port 80 and 443
read -rp "Do you want to forward HTTP (port 80) and HTTPS (port 443) traffic to the Nginx Proxy Manager? [y/N]: " forward_ports
if [[ "$forward_ports" =~ ^[Yy]$ ]]; then
  # Enable IP forwarding
  enable_ip_forwarding

  echo "Setting up firewall rules to forward HTTP and HTTPS traffic..."
  # Forward HTTP
  iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${CONTAINER_IP}:80
  # Forward HTTPS
  iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination ${CONTAINER_IP}:443

  if [ -n "${INTERNAL_SUBNET}" ]; then
    # Allow traffic to leave
    iptables -t nat -A POSTROUTING -s "${INTERNAL_SUBNET}" -o "${PUBLIC_BRIDGE}" -j MASQUERADE
  fi

  # Save the iptables rules
  iptables-save > /etc/iptables/rules.v4
fi

# === Run container setup ===
run_app_container
