#!/bin/bash
# Docker one-liner deploy - run on VPS

docker run -d \
  --name stock-options-lab \
  --restart unless-stopped \
  -p 3000:80 \
  -v /var/www/stock-options-tools:/usr/share/nginx/html:ro \
  nginx:alpine

# OR if files don't exist yet, use this to download and serve:
# docker run -d --name stock-options-lab --restart unless-stopped -p 3000:80 \
#   -e NGINX_ENTRYPOINT_QUIET_LOGS=1 \
#   nginx:alpine sh -c "
#     apt-get update && apt-get install -y curl && \
#     mkdir -p /usr/share/nginx/html && \
#     cd /usr/share/nginx/html && \
#     curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/index.html -o index.html && \
#     curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/styles.css -o styles.css && \
#     curl -sL https://raw.githubusercontent.com/nullficks/stock-options-tools/main/web/main.js -o main.js && \
#     nginx -g 'daemon off;'
#   "
