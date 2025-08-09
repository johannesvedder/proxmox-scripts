#!/bin/bash
# This script sets up an Alpine LXC container with Docker and Nginx Proxy Manager

set -e

echo "🚀 Setting up Alpine LXC with Docker and Nginx Proxy Manager..."

echo "📦 Updating Alpine and installing Docker..."

install_docker

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
      # - "81:81"
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

max_attempts=6
attempt=1
sleep_interval=5

while true; do
  if cd /opt/nginx-proxy-manager && docker-compose ps | grep -q "nginx-proxy-manager.*Up"; then
    echo "✅ Nginx Proxy Manager is running successfully!"
    break
  else
    if (( attempt >= max_attempts )); then
      echo "❌ Nginx Proxy Manager failed to start after $(( max_attempts * sleep_interval )) seconds. Checking logs..."
      cd /opt/nginx-proxy-manager && docker-compose logs
      exit 1
    else
      echo "⏳ Attempt $attempt/$max_attempts: Nginx Proxy Manager is not up yet, waiting $sleep_interval seconds..."
      ((attempt++))
      sleep $sleep_interval
    fi
  fi
done

# echo "📋 Getting container information..."
# NPM_CONTAINER_IP=$(docker inspect nginx-proxy-manager 2>/dev/null | grep '"IPAddress"' | tail -1 | cut -d'"' -f4 || echo "N/A")
# HOST_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "N/A")

echo "🛠️ Creating management script..."
cat > /opt/nginx-proxy-manager/manage.sh << 'EOF'
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

#!/bin/sh

echo "🛠️ Setting up Nginx Proxy Manager to start on boot (Alpine/OpenRC)..."

# Create OpenRC service script
cat > /etc/init.d/nginx-proxy-manager << 'EOF'
#!/sbin/openrc-run

command="/usr/bin/docker-compose"
command_args="up -d"
directory="/opt/nginx-proxy-manager"

depend() {
    after docker
    need docker
    before net
}

start_pre() {
    [ -d "$directory" ] || return 1
}

start() {
    ebegin "Starting Nginx Proxy Manager"
    start-stop-daemon --start --chdir "$directory" --exec "$command" -- $command_args
    eend $?
}

stop() {
    ebegin "Stopping Nginx Proxy Manager"
    start-stop-daemon --stop --exec "$command"
    eend $?
}
EOF

# Make script executable
chmod +x /etc/init.d/nginx-proxy-manager

# Add service to default runlevel
rc-update add nginx-proxy-manager default

# Start the service now
rc-service nginx-proxy-manager start

echo "✅ Nginx Proxy Manager service installed and started."


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

# To access the Nginx Proxy Manager admin interface with SSL via IP address:
# 1. Generate a self-signed certificate:
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /opt/nginx-proxy-manager/ssl.key -out /opt/nginx-proxy-manager/ssl.crt
# 2. Update the Nginx Proxy Manager configuration to use the self-signed certificate
# 3. Create the file http.conf at /opt/nginx-proxy-manager/data/nginx/custom/
# 4. Add the following lines to http.conf:
#server {
#    listen 443 ssl default_server;
#    server_name 192.168.100.101; # Replace with your container's IP address
#
#    ssl_certificate /data/custom_ssl/npm-XX/fullchain.pem;
#    ssl_certificate_key /data/custom_ssl/npm-XX/privkey.pem;
#
#    location / {
#        proxy_pass http://127.0.0.1:81;
#        proxy_set_header Host $host;
#        proxy_set_header X-Real-IP $remote_addr;
#        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#        proxy_set_header X-Forwarded-Proto $scheme;
#    }
#}
# 5. Restart the Nginx Proxy Manager container:
# docker-compose restart nginx-proxy-manager
# 6. Access the admin interface via:
# https://<CONTAINER_IP>/
