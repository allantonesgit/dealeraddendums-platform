#!/bin/bash
# sync.sh — Push local changes to EC2 quickly (after initial deploy)
# Usage: cd /Users/allantone/Sites/dealeraddendums-platform && bash scripts/sync.sh

set -e

EC2_HOST="ec2-54-89-142-76.compute-1.amazonaws.com"
EC2_USER="ubuntu"
PEM="/Users/allantone/ssh/DA2026.pem"
REMOTE_DIR="/var/www/dealeraddendums-platform"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SSH="ssh -i $PEM -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST"

echo "→ Syncing files..."
rsync -az --exclude 'node_modules' --exclude '.git' --exclude 'logs' \
  -e "ssh -i $PEM -o StrictHostKeyChecking=no" \
  "$LOCAL_DIR/" "$EC2_USER@$EC2_HOST:$REMOTE_DIR/"

echo "→ Installing any new dependencies..."
$SSH "cd $REMOTE_DIR && for d in apps/*/; do [ -f \"\$d/package.json\" ] && (cd \"\$d\" && npm install --production --silent); done"

echo "→ Reloading nginx..."
$SSH "sudo nginx -t && sudo systemctl reload nginx"

echo "→ Restarting apps..."
$SSH "cd $REMOTE_DIR && pm2 reload ecosystem.config.js --update-env && pm2 save"

echo ""
echo "✓ Sync complete."
$SSH "pm2 list"
