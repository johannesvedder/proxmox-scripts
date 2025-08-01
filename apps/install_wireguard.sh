#!/bin/bash
# Usage: sudo bash wireguard_setup.sh [interface] [client_name] [client_ip]

INTERFACE="${1:-wg0}"
CLIENT_NAME="${2:-client1}"
CLIENT_IP="${3:-10.0.0.2/24}"
SERVER_IP="10.0.0.1/24"
WG_PORT=51820

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
   echo "Please run as root or sudo"
   exit 1
fi

# Install WireGuard tools
echo "Installing WireGuard..."
apt update
apt install -y wireguard qrencode

# Create keys directory
mkdir -p /etc/wireguard/keys
chmod 700 /etc/wireguard/keys

# Generate server keys if not exist
if [ ! -f /etc/wireguard/keys/server_private.key ]; then
    wg genkey | tee /etc/wireguard/keys/server_private.key | wg pubkey > /etc/wireguard/keys/server_public.key
fi

# Generate client keys if not exist
if [ ! -f /etc/wireguard/keys/${CLIENT_NAME}_private.key ]; then
    wg genkey | tee /etc/wireguard/keys/${CLIENT_NAME}_private.key | wg pubkey > /etc/wireguard/keys/${CLIENT_NAME}_public.key
fi

SERVER_PRIV=$(cat /etc/wireguard/keys/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/keys/server_public.key)
CLIENT_PRIV=$(cat /etc/wireguard/keys/${CLIENT_NAME}_private.key)
CLIENT_PUB=$(cat /etc/wireguard/keys/${CLIENT_NAME}_public.key)

# Get public IP or ask for server public IP
SERVER_PUB_IP=$(curl -s https://ipinfo.io/ip)
read -p "Enter server public IP or domain [$SERVER_PUB_IP]: " input
SERVER_PUB_IP=${input:-$SERVER_PUB_IP}

# Create server config
cat > /etc/wireguard/${INTERFACE}.conf <<EOF
[Interface]
Address = ${SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
SaveConfig = true

# Client peer
[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}
EOF

chmod 600 /etc/wireguard/${INTERFACE}.conf

# Create client config
mkdir -p ~/wireguard-clients
cat > ~/wireguard-clients/${CLIENT_NAME}.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${SERVER_PUB_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "🔑 Client config created at ~/wireguard-clients/${CLIENT_NAME}.conf"

# Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Setup firewall rules (iptables)
echo "Setting up firewall rules..."
iptables -A FORWARD -i ${INTERFACE} -j ACCEPT
iptables -A FORWARD -o ${INTERFACE} -j ACCEPT
iptables -t nat -A POSTROUTING -o $(ip route get 8.8.8.8 | awk '{print $5; exit}') -j MASQUERADE

# Start WireGuard
echo "Starting WireGuard interface ${INTERFACE}..."
wg-quick up ${INTERFACE}

echo "✅ WireGuard server setup complete!"
echo "Use the client config file to connect: ~/wireguard-clients/${CLIENT_NAME}.conf"
