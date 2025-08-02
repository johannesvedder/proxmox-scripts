#!/bin/bash

set -e

if [[ -z "$CTID" ]]; then
  CTID=$(pvesh get /cluster/nextid)
  if [[ $? -ne 0 || -z "$CTID" ]]; then
    echo "❌ Failed to retrieve next available CTID"
    exit 1
  fi
fi

# Ensure script is running from the correct location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ========= Get Template =========
if [[ "$TEMPLATE" == "alpine" ]]; then
  TEMPLATE_PATH=$("$SCRIPT_DIR/../packages/alpine.sh")
else
  echo "❌ Unsupported template: $TEMPLATE"
  exit 1
fi

if [[ -z "$TEMPLATE_PATH" ]]; then
  echo "❌ Failed to retrieve template path"
  exit 1
fi

# ========= Create Container =========
echo "📦 Creating container CTID $CTID with template $TEMPLATE_PATH..."

CMD=(pct create "$CTID" "$TEMPLATE_PATH")

# Optional: Add --hostname only if HOSTNAME is set
[[ -n "$HOSTNAME" ]] && CMD+=(--hostname "$HOSTNAME")

# Required and optional flags
CMD+=(
  --password "$PASSWORD"
  --cores "$CORES"
  --memory "$MEMORY"
  --swap "$SWAP"
  --rootfs "$STORAGE:${DISK}"
  --net0 "name=eth0,bridge=${BRIDGE},ip=dhcp"
  --features nesting=1,keyctl=1
  --unprivileged 1
  --onboot 1
  --start 1
)

# Run the command
"${CMD[@]}"

if [[ $? -ne 0 ]]; then
    echo "❌ Failed to create container $CTID"
    exit 1
fi

echo "✅ Container $CTID created and starting..."

# Wait for container to boot
echo "⏳ Waiting for container to boot..."
sleep 15

# Get the container IP (retry a few times)
CONTAINER_IP=""
for i in {1..5}; do
    CONTAINER_IP=$(pct exec $CTID -- ip -4 addr show dev eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -n "$CONTAINER_IP" ]]; then
        break
    fi
    echo "Waiting for network... ($i/5)"
    sleep 3
done

if [[ -n "$CONTAINER_IP" ]]; then
    echo "✅ Container IP: $CONTAINER_IP" >&2
else
    echo "⚠️  Could not determine container IP, but container is running" >&2
fi

export CTID
echo "Using container CTID: $CTID"
