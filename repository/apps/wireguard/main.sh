#!/bin/bash
# Creates a WireGuard server container on Proxmox VE and configures the host for VPN traffic forwarding.

set -e

# Global network configuration
PUBLIC_BRIDGE="${PUBLIC_BRIDGE:-vmbr0}" # WAN
INTERNAL_BRIDGE="${INTERNAL_BRIDGE:-vmbr1}" # LAN

# WireGuard server configuration
WG_PORT="${WG_PORT:-51820}"
CONTAINER_IP=$(pct exec 102 -- ip -4 addr show dev eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

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
iptables -t nat -A PREROUTING -i "${PUBLIC_BRIDGE}" -p udp --dport "${WG_PORT}" -j DNAT --to-destination "${CONTAINER_IP}":"${WG_PORT}"

# Allow incoming WireGuard traffic to be forwarded to container
iptables -A FORWARD -i "${PUBLIC_BRIDGE}" -o "${INTERNAL_BRIDGE}" -p udp --dport "${WG_PORT}" -d "${CONTAINER_IP}" -j ACCEPT

# Allow container to reply (return traffic)
iptables -A FORWARD -i "${INTERNAL_BRIDGE}" -o "${PUBLIC_BRIDGE}" -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow containers to initiate outbound connections
#iptables -A FORWARD -s 192.168.100.0/24 -o vmbr0 -j ACCEPT

# Allow return traffic from WAN to containers
#iptables -A FORWARD -d 192.168.100.0/24 -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save rules
iptables-save > /etc/iptables/rules.v4

# === Run container setup ===
run_app_container "$SERVER_PUB_IP"
