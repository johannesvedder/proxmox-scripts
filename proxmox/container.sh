# ========== CREATE CONTAINER ==========
echo "🚀 Creating LXC container with CTID $CTID..."
pct create "$CTID" "$TEMPLATE_PATH" \
  --hostname $HOSTNAME \
  --password $PASSWORD \
  --cores "$CORES" \
  --memory "$MEMORY" \
  --swap "$SWAP" \
  --rootfs "$STORAGE:${DISK}" \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --features nesting=1,keyctl=1 \
  --unprivileged 1 \
  --onboot 1 \
  --start 1

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
    echo "✅ Container IP: $CONTAINER_IP"
else
    echo "⚠️  Could not determine container IP, but container is running"
fi
