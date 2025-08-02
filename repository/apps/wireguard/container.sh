#!/bin/bash
# This script sets up a WireGuard VPN server in an Alpine Linux container on Proxmox.

INTERFACE="${1:-wg0}"
CLIENT_NAME="${2:-client1}"
CLIENT_IP="${3:-10.0.0.2/24}"
SERVER_IP="10.0.0.1/24"
WG_PORT=51820

echo "Installing WireGuard..."

ALPINE_VERSION=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')
echo "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main" > /etc/apk/repositories

apk update
apk upgrade

apk add iptables wireguard-tools qrencode

## Install correct WireGuard kernel module based on kernel version
KERNEL_FLAVOR=$(uname -r | grep -oE 'virt|lts' || echo 'virt')
if [ "$KERNEL_FLAVOR" = "lts" ]; then
  apk add wireguard-lts
else
  apk add wireguard-virt
fi

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

echo "Configuring WireGuard firewall rules..."

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Enable forwarding between wg0 and the container's main interface
iptables -A FORWARD -i wg0 -o ${BRIDGE} -j ACCEPT
iptables -A FORWARD -o wg0 -i ${BRIDGE} -m state --state RELATED,ESTABLISHED -j ACCEPT

# Masquerade VPN subnet to container's main interface
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o ${BRIDGE} -j MASQUERADE

iptables-save > /etc/iptables/rules.v4

# Start WireGuard
echo "Starting WireGuard interface ${INTERFACE}..."
wg-quick up ${INTERFACE}

echo "✅ WireGuard server setup complete!"
echo "Use the client config file to connect: ~/wireguard-clients/${CLIENT_NAME}.conf"

# Show QR code for mobile clients
if command -v qrencode &> /dev/null; then
    echo "📱 Generating QR code for mobile clients..."
    qrencode -t ansiutf8 < ~/wireguard-clients/${CLIENT_NAME}.conf
else
    echo "⚠️ qrencode not found, install it to generate QR codes."
fi