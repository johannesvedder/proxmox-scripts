#!/bin/bash
# Usage: sudo bash wireguard_setup.sh [interface] [client_name] [client_ip]

set -e

# if $INTERNAL_BRIDGE is either vmbr1 or use already set value
INTERNAL_BRIDGE="${INTERNAL_BRIDGE:-vmbr0}"

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="wireguard-server"
export CORES="1"
export MEMORY="256"
export SWAP="128"
export DISK="1"

# === Run container creation ===
source "${ROOT_DIR}/proxmox/utils.sh"
create_container

# Get public IP from Proxmox host interface
SERVER_PUB_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
# todo enable
#read -rp "Enter server public IP or domain [$SERVER_PUB_IP]: " input
#SERVER_PUB_IP=${input:-$SERVER_PUB_IP}

# Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Setup firewall rules (iptables)
echo "Setting up firewall rules..."

# DNAT: Forward incoming WireGuard traffic on UDP 51820 to container
iptables -t nat -A PREROUTING -i vmbr0 -p udp --dport 51820 -j DNAT --to-destination 192.168.100.127:51820

# MASQUERADE: Allow containers in 192.168.100.0/24 to reach outside
#iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE

# Allow incoming WireGuard traffic to be forwarded to container
iptables -A FORWARD -i vmbr0 -o vmbr1 -p udp --dport 51820 -d 192.168.100.127 -j ACCEPT

# Allow container to reply (return traffic)
iptables -A FORWARD -i vmbr1 -o vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow containers to initiate outbound connections
#iptables -A FORWARD -s 192.168.100.0/24 -o vmbr0 -j ACCEPT

# Allow return traffic from WAN to containers
#iptables -A FORWARD -d 192.168.100.0/24 -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# todo make this configurable
# IPv4: Allow forwarding from bridge to external (vmbr0)
#iptables -C FORWARD -i ${BRIDGE} -o vmbr0 -j ACCEPT 2>/dev/null || iptables -A FORWARD -i ${BRIDGE} -o vmbr0 -j ACCEPT
#iptables -C FORWARD -o ${BRIDGE} -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A FORWARD -o ${BRIDGE} -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# IPv4: Enable NAT for 192.168.100.0/24 subnet going out vmbr0
#iptables -t nat -C POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o vmbr0 -j MASQUERADE

# IPv6: Allow forwarding (adjust IPv6 bridge subnet as needed)
#ip6tables -C FORWARD -i ${BRIDGE} -o vmbr0 -j ACCEPT 2>/dev/null || ip6tables -A FORWARD -i ${BRIDGE} -o vmbr0 -j ACCEPT
#ip6tables -C FORWARD -o ${BRIDGE} -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || ip6tables -A FORWARD -o ${BRIDGE} -i vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save rules
#iptables-save > /etc/iptables/rules.v4
#ip6tables-save > /etc/iptables/rules.v6

# === Run container setup ===
run_app_container "$SERVER_PUB_IP"
