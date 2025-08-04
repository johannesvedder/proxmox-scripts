#!/bin/bash

enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
}
export -f enable_ip_forwarding