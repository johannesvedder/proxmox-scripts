#!/bin/bash

set -e

dump_environment() {
  local TMP_ENV="/tmp/env_push.sh"

  # Dump exported env vars
  export -p > "$TMP_ENV"

  # Dump functions (Bash-only)
  declare -f >> "$TMP_ENV"

  echo "$TMP_ENV"
}
export -f dump_environment

create_container () {
  # Source the argparse script to parse command line arguments and override defaults
  source "${ROOT_DIR}/helper/argparse.sh"

  # Set and export defaults if not provided
  if [[ -z "$CTID" ]]; then
    CTID=$(pvesh get /cluster/nextid)
    export CTID
    if [[ $? -ne 0 || -z "$CTID" ]]; then
      echo "❌ Failed to retrieve next available CTID"
      exit 1
    fi
  fi

  export TEMPLATE="${TEMPLATE:-alpine}"
  # export HOSTNAME="${HOSTNAME:-alpine-ct}"
  # export PASSWORD="${PASSWORD:-changeme}"
  export STORAGE="${STORAGE:-local-lvm}"
  export BRIDGE="${BRIDGE:-vmbr1}"
  export CORES="${CORES:-2}"
  export MEMORY="${MEMORY:-1024}"
  export SWAP="${SWAP:-512}"
  export DISK="${DISK:-4}"

  # ========= Get Template =========
  if [[ "$TEMPLATE" == "alpine" ]]; then
    TEMPLATE_PATH=$("${ROOT_DIR}/packages/alpine.sh")
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

  # Optional flags: Add only if not set
  [[ -n "$HOSTNAME" ]] && CMD+=(--hostname "$HOSTNAME")
  # [[ -n "$PASSWORD" ]] && CMD+=(--password "$PASSWORD")

  # Required flags
  CMD+=(
    # Asks for password interactively
    --password
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

  # echo "Running command to create container:"
  # printf '  %q ' "${CMD[@]}"

  "${CMD[@]}" # >/dev/null

  if [[ $? -ne 0 ]]; then
      echo "❌ Failed to create container $CTID"
      exit 1
  fi

  echo "✅ Container $CTID created and starting..."

  # Wait for container to boot
  echo "⏳ Waiting for container to boot..."
  # Wait up to 30 seconds for the container to be running
  for i in {1..30}; do
    if pct status "$CTID" | grep -q "running"; then
      echo "✅ Container is running."
      break
    fi
    sleep 1
  done

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
  export CONTAINER_IP

  echo "✅ Container $CTID created successfully with template $TEMPLATE."
}
export -f create_container

run_app_container () {
  if [[ -z "$CTID" ]]; then
    echo "❌ CTID is not set. Cannot run commands in container."
    exit 1
  fi

  echo "📦 Preparing environment for container..."

  pct exec "$CTID" -- sh -c "command -v bash >/dev/null 2>&1 || apk add --no-cache bash"

  local TMP_ENV
  TMP_ENV=$(dump_environment)

  # Push environment and script
  pct push "$CTID" "$TMP_ENV" /root/host_env.sh
  pct exec "$CTID" -- chmod +x /root/host_env.sh
  pct push "$CTID" "${APP_DIR}/container.sh" /root/container.sh
  pct exec "$CTID" -- chmod +x /root/container.sh

  echo "🚀 Running container script with env + args: $*"
  pct exec "$CTID" -- bash -c ". /root/host_env.sh; /root/container.sh \"$@\"" _ "$@"

  # Clean up
  pct exec "$CTID" -- rm -f /root/container.sh /root/host_env.sh
  rm -f "$TMP_ENV"
}

export -f run_app_container
