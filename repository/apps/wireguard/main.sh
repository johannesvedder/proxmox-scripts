#!/bin/bash
# Creates a WireGuard server container on Proxmox VE and configures the host for VPN traffic forwarding.

set -e

# Global network configuration

INTERNAL_BRIDGE="${INTERNAL_BRIDGE:-vmbr1}" # LAN

# WireGuard server configuration
WG_PORT="${WG_PORT:-51820}"

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="wireguard-server"
export CORES="1"
export MEMORY="256"
export SWAP="128"
export DISK="1"

# === Run container creation ===
create_container

enable_ip_forwarding

# Setup firewall rules
echo "Setting up firewall rules..."

# DNAT: Forward incoming WireGuard traffic on UDP to container
#iptables -t nat -A PREROUTING -i "${PUBLIC_BRIDGE}" -p udp --dport "${WG_PORT}" -j DNAT --to-destination "${CONTAINER_IP}":"${WG_PORT}"
ensure_dnat_port_forwarding "udp" "$WG_PORT" "$CONTAINER_IP" "$PUBLIC_BRIDGE"

# Allow incoming WireGuard traffic to be forwarded to container
#iptables -A FORWARD -i "${PUBLIC_BRIDGE}" -o "${INTERNAL_BRIDGE}" -p udp --dport "${WG_PORT}" -d "${CONTAINER_IP}" -j ACCEPT
ensure_forward_rule udp "$WG_PORT" "$CONTAINER_IP" "$PUBLIC_BRIDGE" "$INTERNAL_BRIDGE"

# Allow container to reply (return traffic)
if ! iptables -C FORWARD -i "${INTERNAL_BRIDGE}" -o "${PUBLIC_BRIDGE}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
  iptables -A FORWARD -i "${INTERNAL_BRIDGE}" -o "${PUBLIC_BRIDGE}" -m state --state RELATED,ESTABLISHED -j ACCEPT
  echo "✅ Added FORWARD rule to allow return traffic from ${INTERNAL_BRIDGE} to ${PUBLIC_BRIDGE}"
fi

# Save rules
save_iptables_rules

# === Run container setup ===
run_app_container "$SERVER_PUB_IP"
