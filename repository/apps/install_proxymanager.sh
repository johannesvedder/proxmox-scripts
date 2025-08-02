#!/bin/bash
# Usage: bash install_proxymanager.sh [ctid] [template] [hostname] [password] [storage] [bridge] [cores] [memory] [swap] [disk]
# ctid: container id (default: auto-generated next available ID)
# tempalate: name of the template that should be used (default: alpine)
# hostname: container hostname
# password: root password
# storage: storage pool (default: local-lvm)
# bridge: network bridge (default: vmbr1)
# cores: CPU cores (default: 2)
# memory: RAM in MB (default: 1024)
# swap: swap in MB (default: 512)
# disk: disk size in GB (default: 4)

set -e

# === Defaults ===
export TEMPLATE="alpine"
export HOSTNAME="nginx-proxy-manager"
export CORES="2"
export MEMORY="1024"
export SWAP="512"
export DISK="4"

# === Run container creation ===
source "${ROOT_DIR}/proxmox/container.sh"

# Execute setup commands directly inside the container
echo "🚀 Setting up Alpine LXC with Docker and Nginx Proxy Manager..."

echo "📦 Updating Alpine and installing Docker..."
pct exec $CTID -- apk update
pct exec $CTID -- apk add --no-cache docker docker-compose curl openrc

echo "🐳 Starting Docker service..."
pct exec $CTID -- rc-service docker start
pct exec $CTID -- rc-update add docker default

echo "✅ Verifying Docker installation..."
pct exec $CTID -- docker --version
pct exec $CTID -- docker-compose --version

echo "📁 Creating Nginx Proxy Manager directory structure..."
pct exec $CTID -- mkdir -p /opt/nginx-proxy-manager/{data,letsencrypt,config}

echo "📝 Creating docker-compose.yml..."
pct exec $CTID -- sh -c 'cat > /opt/nginx-proxy-manager/docker-compose.yml << EOF
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      # Public HTTP Port
      - "80:80"
      # Public HTTPS Port
      - "443:443"
      # Admin Web Port
      - "81:81"
    environment:
      # Optional: Set timezone
      TZ: UTC
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
EOF'

echo "🔧 Setting up configuration directories..."
pct exec $CTID -- mkdir -p /opt/nginx-proxy-manager/config /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt
pct exec $CTID -- chmod 755 /opt/nginx-proxy-manager/config /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt

echo "🚀 Starting Nginx Proxy Manager..."
pct exec $CTID -- sh -c 'cd /opt/nginx-proxy-manager && docker-compose up -d'

echo "⏳ Waiting for Nginx Proxy Manager to start..."
sleep 15

echo "🔍 Checking if Nginx Proxy Manager is running..."
if pct exec $CTID -- sh -c 'cd /opt/nginx-proxy-manager && docker-compose ps | grep -q "nginx-proxy-manager.*Up"'; then
    echo "✅ Nginx Proxy Manager is running successfully!"
else
    echo "❌ Nginx Proxy Manager failed to start. Checking logs..."
    pct exec $CTID -- sh -c 'cd /opt/nginx-proxy-manager && docker-compose logs'
    exit 1
fi

echo "📋 Getting container information..."
NPM_CONTAINER_IP=$(pct exec $CTID -- docker inspect nginx-proxy-manager 2>/dev/null | grep '"IPAddress"' | tail -1 | cut -d'"' -f4 || echo "N/A")
HOST_IP=$(pct exec $CTID -- ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "N/A")

echo "🛠️ Creating management script..."
pct exec $CTID -- sh -c 'cat > /opt/nginx-proxy-manager/manage.sh << EOF
#!/bin/bash
# Nginx Proxy Manager Management Script

case "$1" in
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
        echo "Usage: $0 {start|stop|restart|logs|status|update}"
        exit 1
        ;;
esac
EOF'

pct exec $CTID -- chmod +x /opt/nginx-proxy-manager/manage.sh
pct exec $CTID -- ln -sf /opt/nginx-proxy-manager/manage.sh /usr/local/bin/npm-manage

echo ""
echo "🎉 Setup Complete! 🎉"
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
echo "🌐 Nginx Proxy Manager Admin Interface:"
echo "   URL: http://${HOST_IP}:81"
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
echo "🛠️ Management script created: npm-manage {start|stop|restart|logs|status|update}"
