#!/bin/bash

enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    sysctl -w net.ipv4.ip_forward=1
    grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
}
export -f enable_ip_forwarding

ensure_dnat_port_forwarding() {
  local proto="$1"           # tcp or udp
  local port="$2"            # e.g., 80
  local target_ip="$3"       # destination container IP
  local public_if="$4"       # public interface (e.g., vmbr0)

  echo "📡 Ensuring $proto port $port is DNAT forwarded to $target_ip..."

  # --- Check for existing PREROUTING DNAT rules ---
  local existing_dnat
  existing_dnat=$(iptables -t nat -S PREROUTING | grep -- "-p $proto --dport $port" | grep DNAT || true)

  if [[ -n "$existing_dnat" ]]; then
    echo "⚠️ Found existing DNAT rule for $proto port $port:"
    echo "$existing_dnat"

    if ! echo "$existing_dnat" | grep -q "$target_ip"; then
      read -rp "❓ Forwarding goes to another IP. Replace with $target_ip? (y/N): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        local delete_rule
        delete_rule=$(echo "$existing_dnat" | sed 's/^-A /-D /')
        iptables -t nat "$delete_rule"
        echo "✅ Old rule removed."
      else
        echo "⏭️ Skipping $proto port $port."
        return
      fi
    else
      echo "✅ DNAT rule already targets $target_ip. Skipping add."
    fi
  fi

  # --- Add DNAT rule ---
  if ! echo "$existing_dnat" | grep -q "$target_ip"; then
    iptables -t nat -A PREROUTING -i "$public_if" -p "$proto" --dport "$port" -j DNAT --to-destination "${target_ip}:${port}"
    echo "✅ Added DNAT for $proto $port to $target_ip"
  fi
}
export -f ensure_dnat_port_forwarding

ensure_forward_rule() {
  local proto="$1"          # tcp or udp
  local port="$2"           # e.g., 51820 (WireGuard port)
  local target_ip="$3"      # destination container IP
  local public_if="$4"      # public interface (e.g., vmbr0)
  local internal_if="$5"    # internal interface (e.g., vmbr1)

  echo "📡 Ensuring FORWARD rule for $proto port $port to $target_ip..."

  # Check for existing FORWARD rule with matching proto/port but different target IP
  local existing_forward
  existing_forward=$(iptables -S FORWARD | grep -- "-i $public_if -o $internal_if -p $proto --dport $port -d " || true)

  if [[ -n "$existing_forward" ]]; then
    echo "⚠️ Found existing FORWARD rule for $proto port $port:"
    echo "$existing_forward"

    if ! echo "$existing_forward" | grep -q "$target_ip"; then
      read -rp "❓ FORWARD rule points to a different IP. Replace with $target_ip? (y/N): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Convert -A to -D to delete the existing rule
        local delete_rule
        delete_rule=$(echo "$existing_forward" | sed 's/^-A /-D /')
        iptables $delete_rule
        echo "✅ Removed old FORWARD rule."
      else
        echo "⏭️ Skipping FORWARD rule update for $proto port $port."
        return
      fi
    else
      echo "✅ FORWARD rule already points to $target_ip. Skipping add."
      return
    fi
  fi

  # Add the FORWARD rule if not present
  if ! iptables -C FORWARD -i "$public_if" -o "$internal_if" -p "$proto" --dport "$port" -d "$target_ip" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$public_if" -o "$internal_if" -p "$proto" --dport "$port" -d "$target_ip" -j ACCEPT
    echo "✅ Added FORWARD rule for $proto port $port to $target_ip."
  fi
}
export -f ensure_forward_rule

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
