#!/bin/bash
# Deploy stock-options-tools to VPS on port 3000

set -e

WEB_DIR="/var/www/stock-options-tools"
NGINX_CONF="/etc/nginx/sites-available/stock-options-tools"

echo "=== Deploying Stock Options Lab to port 3000 ==="

# Create web directory
sudo mkdir -p $WEB_DIR

# Copy files
cp /home/clawduser/.openclaw/workspace/stock-options-tools/web/index.html $WEB_DIR/
cp /home/clawduser/.openclaw/workspace/stock-options-tools/web/main.js $WEB_DIR/
cp /home/clawduser/.openclaw/workspace/stock-options-tools/web/main.dart.js $WEB_DIR/
cp /home/clawduser/.openclaw/workspace/stock-options-tools/web/styles.css $WEB_DIR/

# Set permissions
sudo chown -R www-data:www-data $WEB_DIR
sudo chmod -R 755 $WEB_DIR

# Create nginx config for port 3000
sudo tee $NGINX_CONF > /dev/null << 'EOF'
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

# Enable and reload
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test and reload
sudo nginx -t && sudo systemctl reload nginx

echo "=== Deployment complete ==="
echo "Access: http://142.132.171.73:3000/"
