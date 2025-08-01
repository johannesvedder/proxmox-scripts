#!/bin/bash
# Usage: bash install_proxymanager [ctid] [hostname] [password] [storage] [bridge] [cores] [memory] [swap] [disk]
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

# TODO

# Create the setup script inside the container
echo "📝 Creating setup script inside container..."
pct exec $CTID -- sh -c 'cat > /tmp/setup_npm.sh << '\''EOF'\''
#!/bin/sh
# Alpine LXC Setup with Docker and Nginx Proxy Manager

set -e

echo "=== Alpine LXC Docker & Nginx Proxy Manager Setup ==="

# Update system and install required packages
echo "Updating Alpine and installing Docker..."
apk update
apk add --no-cache docker docker-compose curl openrc

# Start and enable Docker
echo "Starting Docker service..."
rc-service docker start
rc-update add docker default

# Verify Docker installation
echo "Docker version:"
docker --version
docker-compose --version

# Create directory structure for Nginx Proxy Manager
echo "Creating Nginx Proxy Manager directory structure..."
mkdir -p /opt/nginx-proxy-manager/{data,letsencrypt,config}
cd /opt/nginx-proxy-manager

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat <<COMPOSE_EOF > docker-compose.yml
services:
  nginx-proxy-manager:
    image: '\''jc21/nginx-proxy-manager:latest'\''
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      # Public HTTP Port
      - '\''80:80'\''
      # Public HTTPS Port  
      - '\''443:443'\''
      # Admin Web Port
      - '\''81:81'\''
    environment:
      # Optional: Set timezone
      TZ: '\''UTC'\''
    volumes:
      - ./config:/app/config
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    healthcheck:
      test: ["CMD", "/bin/check-health"]
      interval: 10s
      timeout: 3s
      retries: 3
    networks:
      - proxy-network

networks:
  proxy-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
COMPOSE_EOF

# Create initial configuration directory structure
mkdir -p config data letsencrypt
chmod 755 config data letsencrypt

# Start Nginx Proxy Manager
echo "Starting Nginx Proxy Manager..."
docker-compose up -d

# Wait for container to be ready
echo "Waiting for Nginx Proxy Manager to start..."
sleep 15

# Check if container is running
if docker-compose ps | grep -q "nginx-proxy-manager.*Up"; then
    echo "✅ Nginx Proxy Manager is running successfully!"
else
    echo "❌ Nginx Proxy Manager failed to start. Checking logs..."
    docker-compose logs
    exit 1
fi

# Display access information
NPM_CONTAINER_IP=$(docker inspect nginx-proxy-manager | grep '\''\"IPAddress\"'\'' | tail -1 | cut -d'\''"'\'' -f4)
HOST_IP=$(ip route get 1 | awk '\''{print $7; exit}'\'')

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "🌐 Nginx Proxy Manager Admin Interface:"
echo "   URL: http://$HOST_IP:81"
echo "   Default Email: admin@example.com"
echo "   Default Password: changeme"
echo ""
echo "📋 Container Information:"
echo "   NPM Container IP: $NPM_CONTAINER_IP"
echo "   Host IP: $HOST_IP"
echo "   HTTP Port: 80"
echo "   HTTPS Port: 443"
echo "   Admin Port: 81"
echo ""
echo "🔧 Next Steps:"
echo "1. Access the admin interface and change the default password"
echo "2. Add your domain DNS records pointing to this server IP: $HOST_IP"
echo "3. Create proxy hosts for your services"
echo ""

# Create helper script for managing the service
cat <<MANAGE_EOF > /opt/nginx-proxy-manager/manage.sh
#!/bin/bash
# Nginx Proxy Manager Management Script

case "\$1" in
    start)
        echo "Starting Nginx Proxy Manager..."
        cd /opt/nginx-proxy-manager && docker-compose up -d
        ;;
    stop)
        echo "Stopping Nginx Proxy Manager..."
        cd /opt/nginx-proxy-manager && docker-compose down
        ;;
    restart)
        echo "Restarting Nginx Proxy Manager..."
        cd /opt/nginx-proxy-manager && docker-compose restart
        ;;
    logs)
        echo "Showing Nginx Proxy Manager logs..."
        cd /opt/nginx-proxy-manager && docker-compose logs -f
        ;;
    status)
        echo "Nginx Proxy Manager status:"
        cd /opt/nginx-proxy-manager && docker-compose ps
        ;;
    update)
        echo "Updating Nginx Proxy Manager..."
        cd /opt/nginx-proxy-manager && docker-compose pull && docker-compose up -d
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
MANAGE_EOF

chmod +x /opt/nginx-proxy-manager/manage.sh
ln -sf /opt/nginx-proxy-manager/manage.sh /usr/local/bin/npm-manage

echo "🛠️  Management script created: npm-manage {start|stop|restart|logs|status|update}"
echo ""
echo "🎉 Installation complete! Happy proxying! 🎉"
EOF'

# Make the setup script executable and run it
pct exec $CTID -- chmod +x /tmp/setup_npm.sh
echo "▶️ Running setup script inside container..."
pct exec $CTID -- /tmp/setup_npm.sh

echo ""
echo "✅ Container $CTID is ready and setup completed!"
echo "📋 Container Details:"
echo "   CTID: $CTID"
echo "   Hostname: $HOSTNAME"
echo "   IP: ${CONTAINER_IP:-'DHCP (check with: pct exec $CTID -- ip addr)'}"
echo "   Cores: $CORES"
echo "   Memory: ${MEMORY}MB"
echo "   Disk: ${DISK}GB"
echo ""
echo "🚀 Access Nginx Proxy Manager:"
echo "   http://${CONTAINER_IP:-CONTAINER_IP}:81"
echo "   Default: admin@example.com / changeme"
