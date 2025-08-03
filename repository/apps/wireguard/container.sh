#!/bin/bash
# This script sets up a WireGuard VPN server in an Alpine Linux container on Proxmox.

INTERFACE="${1:-wg0}"
CLIENT_NAME="${2:-client1}"
CLIENT_IP="${3:-10.0.0.2/24}"
SERVER_IP="10.0.0.1/24"
WG_PORT=51820

echo "Installing WireGuard..."

echo "Setting up repositories..."
#setup-apkrepos -cf
cat > /etc/apk/repositories << EOF
https://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/main
https://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community
EOF

apk update
apk upgrade

apk add iptables wireguard-tools libqrencode-tools

# Create keys directory
mkdir -p /etc/wireguard/keys
chmod 700 /etc/wireguard/keys

# Generate server keys if not exist
if [ ! -f /etc/wireguard/keys/server_private.key ]; then
    echo "Generating server keys..."
    wg genkey > /etc/wireguard/keys/server_private.key
    wg pubkey < /etc/wireguard/keys/server_private.key > /etc/wireguard/keys/server_public.key
    chmod 600 /etc/wireguard/keys/server_private.key
fi

# Generate client keys if not exist
if [ ! -f /etc/wireguard/keys/${CLIENT_NAME}_private.key ]; then
    echo "Generating client keys..."
    wg genkey > /etc/wireguard/keys/${CLIENT_NAME}_private.key
    wg pubkey < /etc/wireguard/keys/${CLIENT_NAME}_private.key > /etc/wireguard/keys/${CLIENT_NAME}_public.key
    chmod 600 /etc/wireguard/keys/${CLIENT_NAME}_private.key
fi

SERVER_PRIV=$(cat /etc/wireguard/keys/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/keys/server_public.key)
CLIENT_PRIV=$(cat /etc/wireguard/keys/${CLIENT_NAME}_private.key)
CLIENT_PUB=$(cat /etc/wireguard/keys/${CLIENT_NAME}_public.key)

echo "Server public key: $SERVER_PUB"

# Detect the main network interface
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
echo "Detected main interface: $MAIN_INTERFACE"

# Create server config
cat > /etc/wireguard/${INTERFACE}.conf <<EOF
[Interface]
Address = ${SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
SaveConfig = true

# Enable IP forwarding and NAT
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE

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
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${SERVER_PUB_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo "🔑 Client config created at ~/wireguard-clients/${CLIENT_NAME}.conf"

# Enable IP forwarding permanently
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf

# Create iptables rules directory if it doesn't exist
mkdir -p /etc/iptables

# Enable OpenRC services for persistence
rc-update add iptables
rc-update add ip6tables

# Start WireGuard
echo "Starting WireGuard interface ${INTERFACE}..."
wg-quick up ${INTERFACE}

# Set up WireGuard to start on boot using the proper OpenRC method
echo "Setting up WireGuard service for ${INTERFACE}..."
if [ -f /etc/init.d/wg-quick ]; then
    # Create symbolic link for the interface
    ln -sf /etc/init.d/wg-quick /etc/init.d/wg-quick.${INTERFACE}

    # Enable the service to start on boot
    rc-update add wg-quick.${INTERFACE} default

    echo "✅ WireGuard service wg-quick.${INTERFACE} enabled for boot"
    echo "📝 You can manage the service with:"
    echo "   rc-service wg-quick.${INTERFACE} start"
    echo "   rc-service wg-quick.${INTERFACE} stop"
    echo "   rc-service wg-quick.${INTERFACE} restart"
else
    echo "⚠️ Warning: /etc/init.d/wg-quick not found. WireGuard may not be properly installed."
fi

echo "✅ WireGuard server setup complete!"
echo "📝 Configuration details:"
echo "   - Interface: ${INTERFACE}"
echo "   - Server IP: ${SERVER_IP}"
echo "   - Client IP: ${CLIENT_IP}"
echo "   - Port: ${WG_PORT}"
echo "   - Public endpoint: ${SERVER_PUB_IP}:${WG_PORT}"
echo ""
echo "📁 Client config: ~/wireguard-clients/${CLIENT_NAME}.conf"

# Show QR code for mobile clients
if command -v qrencode &> /dev/null; then
    echo ""
    echo "📱 QR code for mobile clients:"
    qrencode -t ansiutf8 < ~/wireguard-clients/${CLIENT_NAME}.conf
else
    echo "⚠️ qrencode not found. Install it with: apk add qrencode"
fi

# Show current WireGuard status
echo ""
echo "🔍 WireGuard status:"
wg show