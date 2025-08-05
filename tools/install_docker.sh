#!/bin/bash

# Notice: Community Repository is necessary for Docker installation on Alpine Linux.

install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Docker not found, proceeding with installation..."

    apk update
    apk upgrade
    apk add --no-cache docker docker-compose curl openrc

    echo "🐳 Starting Docker service..."
    rc-update add docker default
    service docker start

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
