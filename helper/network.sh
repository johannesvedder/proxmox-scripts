#!/bin/bash

enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
}
export -f enable_ip_forwarding

save_iptables_rules() {
    echo "🔒 Saving iptables rules..."
    if grep -qi alpine /etc/os-release; then
      rc-update add iptables 2>/dev/null
      rc-service iptables save
    elif grep -qi debian /etc/os-release || grep -qi ubuntu /etc/os-release; then
      mkdir -p /etc/iptables
      iptables-save > /etc/iptables/rules.v4
    else
        echo "❌ Unknown system. Please save iptables rules manually."
        return 1
    fi
}
export -f save_iptables_rules
