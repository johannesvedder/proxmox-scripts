#!/bin/bash
# This script sets up Docker on a Proxmox host

set -e

echo "Installing Docker..."

apk update
apk upgrade
apk add --no-cache docker docker-compose curl openrc

echo "🐳 Starting Docker service..."
rc-service docker start
rc-update add docker default

echo "✅ Verifying Docker installation..."
docker --version
docker-compose --version

echo "Docker installation complete."