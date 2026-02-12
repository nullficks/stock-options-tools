#!/bin/bash
# RUN THIS ON THE VPS - Stock Options Lab Deploy Script

set -e

echo "=== Stock Options Lab Deploy ==="

# Stop anything on port 3000
sudo fuser -k 3000/tcp 2>/dev/null || true

# Setup directory
sudo mkdir -p /var/www/stock-options-tools

# Download latest build
cd /tmp
rm -rf stock-options-tools-deploy
mkdir -p stock-options-tools-deploy
cd stock-options-tools-deploy

# Download files from GitHub
curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/index.html -o index.html
curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/styles.css -o styles.css
curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/main.js -o main.js

# Build Dart locally or download pre-built
echo "Downloading pre-built JavaScript..."
curl -sL "https://github.com/nullficks/stock-options-tools/releases/latest/download/main.dart.js" -o main.dart.js 2>/dev/null || echo "No release found, will use placeholder"

# If no prebuilt, we need to build
if [ ! -f main.dart.js ] || [ ! -s main.dart.js ]; then
    echo "Need to build Dart..."
    if ! command -v dart &> /dev/null; then
        echo "Installing Dart..."
        sudo apt-get update
        sudo apt-get install -y apt-transport-https wget gnupg2
        wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
        echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
        sudo apt-get update
        sudo apt-get install -y dart
    fi
    
    # Clone and build
    rm -rf stock-options-tools
    git clone https://github.com/nullficks/stock-options-tools.git
    cd stock-options-tools
    export PATH="$PATH:/usr/lib/dart/bin"
    dart pub get
    dart compile js web/main.dart -O4 -o web/main.dart.js
    cp web/main.dart.js /tmp/stock-options-tools-deploy/
fi

# Copy to web root
cd /tmp/stock-options-tools-deploy
sudo cp index.html styles.css main.js main.dart.js /var/www/stock-options-tools/ 2>/dev/null || true

# Nginx config
sudo tee /etc/nginx/sites-available/stock-options-tools > /dev/null << 'EOF'
server {
    listen 3000;
    server_name _;
    root /var/www/stock-options-tools;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
        add_header Access-Control-Allow-Origin *;
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
}
EOF

sudo ln -sf /etc/nginx/sites-available/stock-options-tools /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo ""
echo "=== DEPLOYED ==="
echo "http://142.132.171.73:3000/"
