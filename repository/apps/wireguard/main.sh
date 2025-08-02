#!/bin/bash
# Usage: sudo bash wireguard_setup.sh [interface] [client_name] [client_ip]

set -e

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="wireguard-server"
export CORES="1"
export MEMORY="256"
export SWAP="128"
export DISK="1"

# === Run container creation ===
source "${ROOT_DIR}/proxmox/container.sh"

# Get public IP from Proxmox host interface
SERVER_PUB_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
read -rp "Enter server public IP or domain [$SERVER_PUB_IP]: " input
SERVER_PUB_IP=${input:-$SERVER_PUB_IP}

# Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Setup firewall rules (iptables)
echo "Setting up firewall rules..."

# todo make this configurable
# Allow forwarding of traffic between bridge and external interface
iptables -A FORWARD -i ${BRIDGE} -o vmbr0 -j ACCEPT
iptables -A FORWARD -o ${BRIDGE} -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Enable NAT for container subnet going out via external interface
iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE
#iptables -t nat -A POSTROUTING -o $(ip route get 8.8.8.8 | awk '{print $5; exit}') -j MASQUERADE

iptables-save > /etc/iptables/rules.v4

# === Run container setup ===
pct push "$CTID" "${APP_DIR}/container.sh" /root/container.sh
pct exec "$CTID" -- sh -c ". /root/container.sh '${SERVER_PUB_IP}'"
pct exec "$CTID" -- rm -f /root/container.sh
