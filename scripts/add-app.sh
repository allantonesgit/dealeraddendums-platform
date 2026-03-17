#!/bin/bash
# add-app.sh — Scaffold a new app and wire it into the platform
# Usage: bash scripts/add-app.sh <slug> "<Display Name>" <port>
# Example: bash scripts/add-app.sh vinlookup "VIN Lookup Tool" 3002

set -e

SLUG=$1
DISPLAY_NAME=$2
PORT=$3

if [ -z "$SLUG" ] || [ -z "$DISPLAY_NAME" ] || [ -z "$PORT" ]; then
  echo "Usage: bash scripts/add-app.sh <slug> \"<Display Name>\" <port>"
  echo "Example: bash scripts/add-app.sh vinlookup \"VIN Lookup Tool\" 3002"
  exit 1
fi

DEPLOY_DIR="/var/www/dealeraddendums-platform"
APP_DIR="$DEPLOY_DIR/apps/$SLUG"

echo "→ Scaffolding app: $DISPLAY_NAME ($SLUG) on port $PORT"

# ── Create app directories ────────────────────────────────────────────────────
mkdir -p "$APP_DIR/public" "$APP_DIR/server"

# ── App package.json ──────────────────────────────────────────────────────────
cat > "$APP_DIR/package.json" << EOF
{
  "name": "$SLUG",
  "version": "1.0.0",
  "description": "$DISPLAY_NAME",
  "main": "server/index.js",
  "scripts": {
    "start": "node server/index.js",
    "dev": "node --watch server/index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

# ── Starter server ────────────────────────────────────────────────────────────
cat > "$APP_DIR/server/index.js" << EOF
const express = require('express');
const path = require('path');
const app = express();

app.use(express.json());
app.use('/$SLUG', express.static(path.join(__dirname, '../public')));

app.get('/$SLUG', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

const PORT = process.env.PORT || $PORT;
app.listen(PORT, () => console.log('$DISPLAY_NAME running on port', PORT));
EOF

# ── Starter frontend ──────────────────────────────────────────────────────────
cat > "$APP_DIR/public/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$DISPLAY_NAME</title>
<style>
  body { font-family: system-ui; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #faf8f4; }
  .card { text-align: center; padding: 3rem; background: white; border-radius: 12px; border: 1px solid rgba(0,0,0,0.08); }
  h1 { font-size: 1.5rem; color: #0f2744; margin-bottom: 0.5rem; }
  p { color: #6b7a8f; font-size: 0.9rem; }
  a { color: #c9963a; }
</style>
</head>
<body>
  <div class="card">
    <h1>$DISPLAY_NAME</h1>
    <p>App scaffold ready. Edit <code>apps/$SLUG/public/index.html</code> to build this app.</p>
    <p><a href="/">← Back to platform home</a></p>
  </div>
</body>
</html>
EOF

# ── Install dependencies ──────────────────────────────────────────────────────
echo "→ Installing dependencies..."
(cd "$APP_DIR" && npm install --silent)

# ── Add to ecosystem.config.js ───────────────────────────────────────────────
echo "→ Adding to PM2 ecosystem..."
NEW_APP_BLOCK="    {
      name: '$SLUG',
      script: 'apps/$SLUG/server/index.js',
      cwd: '$DEPLOY_DIR',
      env: { NODE_ENV: 'production', PORT: $PORT },
      instances: 1, autorestart: true, watch: false,
      error_file: 'logs/$SLUG-err.log',
      out_file: 'logs/$SLUG-out.log'
    },"
# Insert before the closing ]; in ecosystem.config.js
sed -i "s|  \]|  $NEW_APP_BLOCK\n  ]|" "$DEPLOY_DIR/ecosystem.config.js"

# ── Add to nginx config ───────────────────────────────────────────────────────
echo "→ Adding nginx route..."
NEW_NGINX_BLOCK="    location /$SLUG {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }"
sed -i "s|# ── Add new apps below|$NEW_NGINX_BLOCK\n\n    # ── Add new apps below|" "$DEPLOY_DIR/nginx/apps.conf"
sudo nginx -t && sudo systemctl reload nginx

# ── Start app in PM2 ─────────────────────────────────────────────────────────
pm2 start "$DEPLOY_DIR/ecosystem.config.js" --only $SLUG
pm2 save

# ── Register with homepage ────────────────────────────────────────────────────
echo "→ Registering with homepage..."
APPS_REGISTRY="$DEPLOY_DIR/apps/homepage/apps-registry.json"
if [ -f "$APPS_REGISTRY" ]; then
  node -e "
    const fs = require('fs');
    const reg = JSON.parse(fs.readFileSync('$APPS_REGISTRY','utf8'));
    reg.apps.push({ slug: '$SLUG', name: '$DISPLAY_NAME', port: $PORT, status: 'active', added: new Date().toISOString().split('T')[0] });
    fs.writeFileSync('$APPS_REGISTRY', JSON.stringify(reg, null, 2));
    console.log('Registry updated.');
  "
fi

echo ""
echo "✓ App '$DISPLAY_NAME' is live at: https://apps.dealeraddendums.com/$SLUG"
echo "  Edit:   apps/$SLUG/public/index.html"
echo "  Server: apps/$SLUG/server/index.js"
echo "  Logs:   pm2 logs $SLUG"
