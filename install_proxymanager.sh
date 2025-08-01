# TODO create alpine latest lxc with 2 vCPU, 1 GB RAM, 4 GB Disk

# Install Docker
apk update
apk add docker
rc-service docker start
rc-update add docker default
service docker start
addgroup ${USER} docker
docker --version

# Install nginx proxymanager

# todo create docker-compose.yml
# todo add:
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      # These ports are in format <host-port>:<container-port>
      - '80:80' # Public HTTP Port
      - '443:443' # Public HTTPS Port
      - '81:81' # Admin Web Port
      # Add any other Stream port you want to expose
      # - '21:21' # FTP

    #environment:
      # Uncomment this if you want to change the location of
      # the SQLite DB file within the container
      # DB_SQLITE_FILE: "/data/database.sqlite"

      # Uncomment this if IPv6 is not enabled on your host
      # DISABLE_IPV6: 'true'

    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
docker compose up -d

# todo configure proxymanager so that i can add subdomains and link them to my services in other proxmox containers e.g. app1.mydomain.example -> app1 container
