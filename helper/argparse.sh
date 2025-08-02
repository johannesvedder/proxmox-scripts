#!/bin/bash

set -e

# === Parse Flags ===
PARSED=$(getopt -o "" \
  --long ctid:,template:,hostname:,password:,storage:,bridge:,cores:,memory:,swap:,disk: \
  -- "$@")

if [[ $? -ne 0 ]]; then
  echo "❌ Failed to parse arguments."
  exit 1
fi

eval set -- "$PARSED"

while true; do
  case "$1" in
    --ctid) CTID="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --hostname) HOSTNAME="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --bridge) BRIDGE="$2"; shift 2 ;;
    --cores) CORES="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --swap) SWAP="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "❌ Invalid option: $1"; exit 1 ;;
  esac
done

export CTID TEMPLATE HOSTNAME PASSWORD STORAGE BRIDGE CORES MEMORY SWAP DISK
