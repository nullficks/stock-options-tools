#!/bin/bash
# Deploy Stock Options Lab to VPS
# Run this on the VPS after uploading the web folder

set -e

DOMAIN="options.brennpunkt-index.de"
WEB_ROOT="/var/www/stock-options-tools"
NGINX_CONF="/etc/nginx/sites-available/stock-options-tools"
PORT="3000"

echo "=== Stock Options Lab VPS Deploy Script ==="

# Install Dart if not present
if ! command -v dart &> /dev/null; then
    echo "Installing Dart SDK..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https wget gnupg2
    wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
    echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
    sudo apt-get update
    sudo apt-get install -y dart
    echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.bashrc
    export PATH="$PATH:/usr/lib/dart/bin"
fi

# Create web root
echo "Setting up web directory..."
sudo mkdir -p $WEB_ROOT

# Copy files (assumes this script is run from project root)
echo "Copying web files..."
sudo cp -r web/* $WEB_ROOT/

# Build Dart to JavaScript
echo "Building Dart to JavaScript..."
cd /tmp
if [ ! -d "stock-options-tools-build" ]; then
    git clone https://github.com/nullficks/stock-options-tools.git stock-options-tools-build
fi
cd stock-options-tools-build
dart pub get
dart compile js web/main.dart -O4 -o web/main.dart.js
sudo cp web/main.dart.js $WEB_ROOT/

# Set permissions
sudo chown -R www-data:www-data $WEB_ROOT
sudo chmod -R 755 $WEB_ROOT

# Create nginx config
echo "Creating nginx configuration..."
sudo tee $NGINX_CONF > /dev/null << 'EOF'
server {
    listen 80;
    server_name options.brennpunkt-index.de;
    root /var/www/stock-options-tools;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Enable gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
EOF

# Enable site
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "=== Deployment Complete ==="
echo "Site should be available at: http://$DOMAIN"
echo ""
echo "To set up SSL with Let's Encrypt:"
echo "  sudo certbot --nginx -d $DOMAIN"
