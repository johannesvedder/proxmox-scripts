#!/bin/bash
# Usage: bash setup_proxmox_hetzner.sh [dhcp_enabled]
# dhcp_enabled: true or false (default: true)
# Run: bash -c "$(curl -fsSL <RAW_URL>)"

DHCP_ENABLED=${1:-true}

INTERNAL_BRIDGE="vmbr1"
INTERNAL_SUBNET="192.168.100.0/24"
INTERNAL_NETMASK="255.255.255.0"
INTERNAL_IP="192.168.100.1"
DHCP_RANGE_START="192.168.100.100"
DHCP_RANGE_END="192.168.100.200"

PUBLIC_BRIDGE="vmbr0"
PUBLIC_IP=$(ip -4 addr show dev $PUBLIC_BRIDGE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)

echo "DHCP enabled: $DHCP_ENABLED"
echo "Public bridge: $PUBLIC_BRIDGE, IP: $PUBLIC_IP, Gateway: $GATEWAY"

# 1. Create internal bridge if missing
if ! ip link show $INTERNAL_BRIDGE &>/dev/null; then
  echo "Creating $INTERNAL_BRIDGE with IP $INTERNAL_IP"
  cat <<EOF >> /etc/network/interfaces

auto $INTERNAL_BRIDGE
iface $INTERNAL_BRIDGE inet static
    address $INTERNAL_IP/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

  # Restart networking to apply the new interface
  echo "Restarting networking to apply new interface..."
  systemctl restart networking
  
  # Wait a moment for interface to come up
  sleep 2
else
  echo "$INTERNAL_BRIDGE already exists"
fi

# 2. Enable IP forwarding
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# 3. Setup NAT on public bridge
echo "Configuring NAT MASQUERADE on $PUBLIC_BRIDGE for $INTERNAL_SUBNET"

# Remove existing rule if it exists (ignore errors)
iptables -t nat -D POSTROUTING -s $INTERNAL_SUBNET -o $PUBLIC_BRIDGE -j MASQUERADE 2>/dev/null || true

# Add the MASQUERADE rule
iptables -t nat -A POSTROUTING -s $INTERNAL_SUBNET -o $PUBLIC_BRIDGE -j MASQUERADE

# Verify the rule was added
echo "Current NAT rules:"
iptables -t nat -L POSTROUTING -nv --line-numbers

# 4. Persist iptables rules
if ! dpkg -l | grep -qw iptables-persistent; then
  echo "Installing iptables-persistent..."
  
  # Pre-configure debconf selections for headless installation
  echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
  echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
  
  apt-get update && apt-get install -y iptables-persistent
else
  echo "iptables-persistent already installed"
fi

# Save current rules
echo "Saving iptables rules..."
netfilter-persistent save

# 5. DHCP server (optional)
if [[ "$DHCP_ENABLED" == "true" ]]; then
  echo "Installing/configuring ISC DHCP server..."

  apt-get install -y isc-dhcp-server

  # Configure which interface DHCP should listen on
  sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$INTERNAL_BRIDGE\"/" /etc/default/isc-dhcp-server

  # Backup original config if it exists
  [ ! -f /etc/dhcp/dhcpd.conf.orig ] && cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig

  # Create DHCP configuration
  cat <<EOF >/etc/dhcp/dhcpd.conf
default-lease-time 600;
max-lease-time 7200;

subnet 192.168.100.0 netmask $INTERNAL_NETMASK {
  range $DHCP_RANGE_START $DHCP_RANGE_END;
  option routers $INTERNAL_IP;
  option domain-name-servers 1.1.1.1, 8.8.8.8;
}
EOF

  # Restart and enable DHCP server
  systemctl restart isc-dhcp-server
  systemctl enable isc-dhcp-server
  
  # Check DHCP server status
  if systemctl is-active --quiet isc-dhcp-server; then
    echo "DHCP server is running successfully"
  else
    echo "Warning: DHCP server failed to start. Check logs with: journalctl -u isc-dhcp-server"
  fi
else
  echo "DHCP server installation skipped."
fi

echo ""
echo "=== Setup Complete! ==="
echo "Bridge $INTERNAL_BRIDGE configured with IP $INTERNAL_IP"
echo "Internal subnet: $INTERNAL_SUBNET"
echo "DHCP enabled: $DHCP_ENABLED"
echo ""
echo "To verify NAT is working:"
echo "  iptables -t nat -L POSTROUTING -nv --line-numbers"
echo ""
echo "Use bridge '$INTERNAL_BRIDGE' for your LXC containers and VMs."
