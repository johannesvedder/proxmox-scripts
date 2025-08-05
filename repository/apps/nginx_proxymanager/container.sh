#!/bin/bash
# This script sets up an Alpine LXC container with Docker and Nginx Proxy Manager

set -e

echo "🚀 Setting up Alpine LXC with Docker and Nginx Proxy Manager..."

echo "📦 Updating Alpine and installing Docker..."

. "${ROOT_DIR}/tools/install_docker.sh"

echo "📁 Creating Nginx Proxy Manager directory structure..."
mkdir -p /opt/nginx-proxy-manager/{data,letsencrypt,config}

echo "📝 Creating docker-compose.yml..."
cat > /opt/nginx-proxy-manager/docker-compose.yml << EOF
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
EOF

echo "🔧 Setting up configuration directories..."
mkdir -p /opt/nginx-proxy-manager/config /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt
chmod 755 /opt/nginx-proxy-manager/config /opt/nginx-proxy-manager/data /opt/nginx-proxy-manager/letsencrypt

echo "🚀 Starting Nginx Proxy Manager..."
cd /opt/nginx-proxy-manager && docker-compose up -d

echo "⏳ Waiting for Nginx Proxy Manager to start..."
sleep 15

echo "🔍 Checking if Nginx Proxy Manager is running..."
if cd /opt/nginx-proxy-manager && docker-compose ps | grep -q "nginx-proxy-manager.*Up"; then
    echo "✅ Nginx Proxy Manager is running successfully!"
else
    echo "❌ Nginx Proxy Manager failed to start. Checking logs..."
    cd /opt/nginx-proxy-manager && docker-compose logs
    exit 1
fi

# echo "📋 Getting container information..."
# NPM_CONTAINER_IP=$(docker inspect nginx-proxy-manager 2>/dev/null | grep '"IPAddress"' | tail -1 | cut -d'"' -f4 || echo "N/A")
# HOST_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "N/A")

echo "🛠️ Creating management script..."
cat > /opt/nginx-proxy-manager/manage.sh << EOF
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
EOF

chmod +x /opt/nginx-proxy-manager/manage.sh
ln -sf /opt/nginx-proxy-manager/manage.sh /usr/local/bin/npm-manage

echo ""
echo "🎉 Setup Complete! 🎉"
echo ""
echo "✅ Container $CTID is ready and setup completed!"
echo "   HTTP Port: 80"
echo "   HTTPS Port: 443"
echo "   Admin Port: 81"
echo ""
echo "🌐 Nginx Proxy Manager Admin Interface:"
echo "   URL: http://${CONTAINER_IP}:81"
echo "   Default Email: admin@example.com"
echo "   Default Password: changeme"
echo ""
echo "🛠️ Management script created: npm-manage {start|stop|restart|logs|status|update}"
