#!/bin/bash
# This script sets up a WireGuard VPN server in an Alpine Linux container on Proxmox.

SERVER_PUB_IP="${1}"
INTERFACE="${2:-wg0}"
CLIENT_NAME="${3:-client1}"
CLIENT_IP="${4:-10.0.0.2/32}"
SERVER_IP="10.0.0.1/24"
WG_PORT=51820

# check if SERVER_PUB_IP is provided
if [ -z "$SERVER_PUB_IP" ]; then
    echo "Usage: $0 <server_public_ip> [interface] [client_name] [client_ip]"
    echo "Example: $0"
fi

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

# Use restrictive file permissions when generating keys
umask 077

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

# Enable IP forwarding permanently (IPv4 + IPv6)
grep -qxF 'net.ipv4.ip_forward = 1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.all.forwarding = 1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Setup iptables rules (IPv4 + IPv6) with persistence
iptables -A FORWARD -i ${INTERFACE} -j ACCEPT
iptables -A FORWARD -o ${INTERFACE} -j ACCEPT
iptables -t nat -A POSTROUTING -o ${MAIN_IF} -j MASQUERADE

ip6tables -A FORWARD -i ${INTERFACE} -j ACCEPT
ip6tables -A FORWARD -o ${INTERFACE} -j ACCEPT
ip6tables -t nat -A POSTROUTING -o ${MAIN_IF} -j MASQUERADE

# Save iptables rules for persistence
mkdir -p /etc/iptables
iptables-save > /etc/iptables/iptables.rules
ip6tables-save > /etc/iptables/ip6tables.rules

# Create restore scripts for boot
cat > /etc/local.d/iptables.start <<EOF
#!/bin/sh
iptables-restore < /etc/iptables/iptables.rules
ip6tables-restore < /etc/iptables/ip6tables.rules
EOF
chmod +x /etc/local.d/iptables.start
rc-update add local default

# Create server config
cat > /etc/wireguard/${INTERFACE}.conf <<EOF
[Interface]
Address = ${SERVER_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV}
SaveConfig = true

# Enable IP forwarding and NAT
PostUp = sysctl -w net.ipv4.ip_forward=1; sysctl -w net.ipv6.conf.all.forwarding=1
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${MAIN_IF} -j MASQUERADE
PostUp = ip6tables -A FORWARD -i %i -j ACCEPT
PostUp = ip6tables -A FORWARD -o %i -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o ${MAIN_IF} -j MASQUERADE

PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${MAIN_IF} -j MASQUERADE
PostDown = ip6tables -D FORWARD -i %i -j ACCEPT
PostDown = ip6tables -D FORWARD -o %i -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o ${MAIN_IF} -j MASQUERADE

# Client peer
[Peer]
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}
EOF

chmod 600 /etc/wireguard/${INTERFACE}.conf

# Create client config
mkdir -p ~/wireguard-clients
chmod 700 ~/wireguard-clients

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

chmod 600 ~/wireguard-clients/${CLIENT_NAME}.conf

echo "🔑 Client config created at ~/wireguard-clients/${CLIENT_NAME}.conf"

# Enable IP forwarding permanently
# echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf

# Create iptables rules directory if it doesn't exist
#mkdir -p /etc/iptables

# Enable OpenRC services for persistence
#rc-update add iptables
#rc-update add ip6tables

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
