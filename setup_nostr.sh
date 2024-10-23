#!/bin/bash

# Function to wait for apt to be available
function wait_for_apt() {
  while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo 'Waiting for apt locks to be released...'
    sleep 5
  done
}

# Function to handle apt operations with retries
function apt_get_wrapper() {
  local max_attempts=30
  local attempt=1
  while [ $attempt -le $max_attempts ]; do
    if ! sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && ! sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
      sudo apt-get $@ && break
    fi
    echo "Attempt $attempt/$max_attempts: apt is locked. Waiting..."
    sleep 10
    attempt=$((attempt + 1))
  done
  if [ $attempt -gt $max_attempts ]; then
    echo "Failed to execute apt-get after $max_attempts attempts"
    exit 1
  fi
}

# Wait for any initial apt operations to complete
wait_for_apt

# Use the wrapper function for apt operations
apt_get_wrapper update
apt_get_wrapper upgrade -y

# Install dependencies
apt_get_wrapper install -y git postgresql postgresql-contrib

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. $HOME/.cargo/env

# Set up PostgreSQL
sudo -u postgres psql -c "CREATE USER nostr WITH PASSWORD 'bmwbmwbmwbmw';"
sudo -u postgres psql -c "CREATE DATABASE nostr OWNER nostr;"

# Clone and build nostr-rs-relay
git clone https://github.com/scsibug/nostr-rs-relay.git
cd nostr-rs-relay
cargo build --release

# Move config file to the correct location
mv /tmp/config.toml /root/nostr-rs-relay/config.toml

# Move systemd service file to the correct location
mv /tmp/nostr-rs-relay.service /etc/systemd/system/nostr-rs-relay.service

# Enable and start the service
systemctl daemon-reload
systemctl enable nostr-rs-relay
systemctl start nostr-rs-relay

# Install and configure Nginx
apt_get_wrapper install -y nginx
mv /tmp/nginx-nostr-rs-relay.conf /etc/nginx/sites-available/nostr-rs-relay
ln -s /etc/nginx/sites-available/nostr-rs-relay /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

# Install Certbot and obtain SSL certificate
#apt_get_wrapper install -y certbot python3-certbot-nginx

# Run certbot with --staging flag first to test
#certbot --nginx \
#  --staging \
#  -d ${DOMAIN} \
#  --non-interactive \
#  --agree-tos \
#  --email ${EMAIL} \
#  --verbose

## If staging succeeds, run for real
#if [ $? -eq 0 ]; then
#  certbot --nginx \
#    -d ${DOMAIN} \
#    --non-interactive \
#    --agree-tos \
#    --email ${EMAIL}
#else
#  echo "Certbot staging failed, skipping production certificate"
#  exit 1
#fi