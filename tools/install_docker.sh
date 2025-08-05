#!/bin/bash
# This script sets up Docker on a Proxmox host

set -e

install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker not found, proceeding with installation..."

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
  else
    echo "Docker is already installed."
    return
  fi
}

export -f install_docker
