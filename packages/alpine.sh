#!/bin/bash
# Usage: bash alpine.sh

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
