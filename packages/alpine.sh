#!/bin/bash
# Usage: bash alpine.sh [ctid] [hostname] [password] [storage] [bridge] [cores] [memory] [swap] [disk]
# ctid: container id (default: auto-generated next available ID)
# hostname: container hostname (default: alpine-npm)
# password: root password (default: changeme)
# storage: storage pool (default: local-lvm)
# bridge: network bridge (default: vmbr1)
# cores: CPU cores (default: 2)
# memory: RAM in MB (default: 1024)
# swap: swap in MB (default: 512)
# disk: disk size in GB (default: 4)

CTID="${1:-$(pvesh get /cluster/nextid)}"
HOSTNAME="${2:-alpine-npm}"
PASSWORD="${3:-changeme}"
STORAGE="${4:-local-lvm}"
BRIDGE="${5:-vmbr1}"
CORES="${6:-2}"
MEMORY="${7:-1024}"
SWAP="${8:-512}"
DISK="${9:-4}"  # in GB

TEMPLATE_DIR="/var/lib/vz/template/cache"

# ========== GET LATEST ALPINE TEMPLATE ==========
echo "🔍 Updating available templates list..."
pveam update

echo "🔍 Finding latest Alpine template..."
TEMPLATE_NAME=$(pveam available --section system | grep "alpine.*amd64" | sort -V | tail -n 1 | awk '{print $2}')

if [[ -z "$TEMPLATE_NAME" ]]; then
  echo "❌ Failed to find Alpine template."
  exit 1
fi

TEMPLATE_PATH="${TEMPLATE_DIR}/${TEMPLATE_NAME}"

# ========== CHECK LOCAL TEMPLATE ==========
if [[ -f "$TEMPLATE_PATH" ]]; then
  echo "✅ Template already exists locally: $TEMPLATE_NAME"
else
  echo "⬇️  Downloading template: $TEMPLATE_NAME"
  pveam download local "$TEMPLATE_NAME"
  if [[ $? -ne 0 ]]; then
    echo "❌ Failed to download the template."
    exit 1
  fi
  echo "✅ Template downloaded: $TEMPLATE_NAME"
fi

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

