#!/bin/bash
# deploy.sh — Pull latest from GitHub and restart all apps
# Usage: bash scripts/deploy.sh
# Or from anywhere: cd /var/www/dealeraddendums-platform && bash scripts/deploy.sh

set -e
DEPLOY_DIR="/var/www/dealeraddendums-platform"

echo ""
echo "→ Deploying latest from GitHub..."
cd $DEPLOY_DIR
git pull origin main

echo "→ Installing any new dependencies..."
for app_dir in apps/*/; do
  if [ -f "$app_dir/package.json" ]; then
    (cd "$app_dir" && npm install --production --silent)
  fi
done

echo "→ Reloading nginx config..."
sudo nginx -t && sudo systemctl reload nginx

echo "→ Restarting apps..."
pm2 reload ecosystem.config.js --update-env

echo ""
echo "✓ Deploy complete. Running apps:"
pm2 list
