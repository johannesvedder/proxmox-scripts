#!/bin/bash
# Configures Proxmox for Hetzner Cloud with NAT and DHCP

# Use config or defaults
INTERNAL_BRIDGE="${INTERNAL_BRIDGE:-vmbr1}" # LAN
INTERNAL_SUBNET="${INTERNAL_SUBNET:-192.168.100.0/24}"
INTERNAL_NETMASK="${INTERNAL_NETMASK:-255.255.255.0}"
INTERNAL_IP="${INTERNAL_IP:-192.168.100.1}"
DHCP_RANGE_START="${DHCP_RANGE_START:-192.168.100.100}"
DHCP_RANGE_END="${DHCP_RANGE_END:-192.168.100.200}"
PUBLIC_BRIDGE="${PUBLIC_BRIDGE:-vmbr0}" # WAN

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
enable_ip_forwarding

# 3. # Add the MASQUERADE rule if not already present
echo "Configuring NAT MASQUERADE on $PUBLIC_BRIDGE for $INTERNAL_SUBNET"
if ! iptables -t nat -C POSTROUTING -s $INTERNAL_SUBNET -o $PUBLIC_BRIDGE -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s $INTERNAL_SUBNET -o $PUBLIC_BRIDGE -j MASQUERADE
fi

# 4. Persist iptables rules
save_iptables_rules

# 5. DHCP server (optional)
# Check if DHCP server should be installed
read -rp "Do you want to install and configure the ISC DHCP server? [Y/n]: " dhcp_choice
dhcp_choice=${dhcp_choice:-n}
if [[ "$dhcp_choice" =~ ^[Yy]$ ]]; then
  echo "Installing/configuring ISC DHCP server..."

  apt-get install -y isc-dhcp-server

  # Configure which interface DHCP should listen on
  echo "Configuring DHCP server to listen on $INTERNAL_BRIDGE"
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

# Updating config file
update_config "INTERNAL_BRIDGE" "$INTERNAL_BRIDGE"
update_config "INTERNAL_SUBNET" "$INTERNAL_SUBNET"
update_config "INTERNAL_NETMASK" "$INTERNAL_NETMASK"
update_config "INTERNAL_IP" "$INTERNAL_IP"
update_config "DHCP_ENABLED" "$DHCP_ENABLED"
update_config "DHCP_RANGE_START" "$DHCP_RANGE_START"
update_config "DHCP_RANGE_END" "$DHCP_RANGE_END"
update_config "PUBLIC_BRIDGE" "$PUBLIC_BRIDGE"

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
