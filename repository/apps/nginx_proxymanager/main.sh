#!/bin/bash

set -e

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="nginx-proxy-manager"
export CORES="2"
export MEMORY="1024"
export SWAP="512"
export DISK="4"

# === Run container creation ===
create_container

# Ask user if they want to forward port 80 and 443
read -rp "Do you want to forward HTTP (port 80) and HTTPS (port 443) traffic to the Nginx Proxy Manager? [y/N]: " forward_ports
if [[ "$forward_ports" =~ ^[Yy]$ ]]; then
  # Enable IP forwarding
  enable_ip_forwarding

  echo "Setting up firewall rules to forward all incoming HTTP (80) and HTTPS (443) traffic (${PUBLIC_BRIDGE}) to the Nginx Proxy Manager container (${CONTAINER_IP})."

  # Forwarding ports 80 and 443
  # Define target container IP and public bridge
  TARGET_IP="${CONTAINER_IP}"
  PORTS=(80 443)

  for PORT in "${PORTS[@]}"; do
    # Look for existing DNAT rules on this port (regardless of target IP)
    EXISTING_RULE=$(iptables -t nat -S PREROUTING | grep -- "-p tcp --dport $PORT" | grep DNAT)

    if [[ -n "$EXISTING_RULE" ]]; then
      echo "⚠️ Found existing DNAT rule for port $PORT:"
      echo "$EXISTING_RULE"

      # Check if it's targeting a different IP than desired
      if ! echo "$EXISTING_RULE" | grep -q "$TARGET_IP"; then
        echo "❓ This rule forwards to a different IP than $TARGET_IP."
        read -rp "🧼 Do you want to remove the existing rule and replace it with one for $TARGET_IP? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
          # Extract rule spec for deletion
          DELETE_RULE=$(echo "$EXISTING_RULE" | sed 's/^-A /-D /')
          iptables -t nat $DELETE_RULE
          echo "✅ Removed old rule."

          # Add new rule
          iptables -t nat -A PREROUTING -i "$PUBLIC_BRIDGE" -p tcp --dport "$PORT" -j DNAT --to-destination "$TARGET_IP:$PORT"
          echo "✅ Added new rule for port $PORT to $TARGET_IP."
        else
          echo "⏭️ Skipping port $PORT."
        fi
      else
        echo "✅ Rule already exists for port $PORT and points to the correct IP. Skipping."
      fi
    else
      # No rule exists — just add it
      iptables -t nat -A PREROUTING -i "$PUBLIC_BRIDGE" -p tcp --dport "$PORT" -j DNAT --to-destination "$TARGET_IP:$PORT"
      echo "✅ Added rule for port $PORT to $TARGET_IP."
    fi
  done

  if [ -n "${INTERNAL_SUBNET}" ]; then
    if ! iptables -t nat -C POSTROUTING -s "${INTERNAL_SUBNET}" -o "${PUBLIC_BRIDGE}" -j MASQUERADE 2>/dev/null; then
      echo "Configuring NAT MASQUERADE on ${PUBLIC_BRIDGE} for ${INTERNAL_SUBNET}"
      # Allow traffic to leave
      iptables -t nat -A POSTROUTING -s "${INTERNAL_SUBNET}" -o "${PUBLIC_BRIDGE}" -j MASQUERADE
    fi
  fi

  save_iptables_rules
fi

# === Run container setup ===
run_app_container
