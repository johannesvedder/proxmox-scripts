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

  echo "Setting up firewall rules to forward all incoming HTTP (80) and HTTPS (443) traffic (${PUBLIC_BRIDGE}) to the Nginx Proxy Manager container (${CONTAINER_IP})."

  #if ! iptables -t nat -C PREROUTING -i "${PUBLIC_BRIDGE}" -p tcp --dport 80 -j DNAT --to-destination ${CONTAINER_IP}:80 2>/dev/null; then
    # Forward HTTP
  #  iptables -t nat -A PREROUTING -i "${PUBLIC_BRIDGE}" -p tcp --dport 80 -j DNAT --to-destination ${CONTAINER_IP}:80
  #fi
  #if ! iptables -t nat -C PREROUTING -i "${PUBLIC_BRIDGE}" -p tcp --dport 443 -j DNAT --to-destination ${CONTAINER_IP}:443 2>/dev/null; then
    # Forward HTTPS
  #  iptables -t nat -A PREROUTING -i "${PUBLIC_BRIDGE}" -p tcp --dport 443 -j DNAT --to-destination ${CONTAINER_IP}:443
  #fi
  # Forwarding ports 80 and 443
  ensure_dnat_port_forwarding "tcp" 80 "$CONTAINER_IP" "$PUBLIC_BRIDGE"
  ensure_dnat_port_forwarding "tcp" 443 "$CONTAINER_IP" "$PUBLIC_BRIDGE"

  if [ -n "${INTERNAL_SUBNET}" ]; then
    if ! iptables -t nat -C POSTROUTING -s "${INTERNAL_SUBNET}" -o "${PUBLIC_BRIDGE}" -j MASQUERADE 2>/dev/null; then
      echo "Configuring NAT MASQUERADE on ${PUBLIC_BRIDGE} for ${INTERNAL_SUBNET}"
      # Allow traffic to leave
      iptables -t nat -A POSTROUTING -s "${INTERNAL_SUBNET}" -o "${PUBLIC_BRIDGE}" -j MASQUERADE
    fi
  fi

  save_iptables_rules
fi

# === Run container setup ===
run_app_container
