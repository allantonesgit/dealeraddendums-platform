#!/bin/bash
# mac-deploy.sh — Run from your Mac to push files to EC2 and bootstrap everything
# Usage: cd /Users/allantone/Sites/dealeraddendums-platform && bash scripts/mac-deploy.sh

set -e

EC2_HOST="ec2-54-89-142-76.compute-1.amazonaws.com"
EC2_USER="ubuntu"
PEM="/Users/allantone/ssh/DA2026.pem"
REMOTE_DIR="/var/www/dealeraddendums-platform"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

SSH="ssh -i $PEM -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST"
SCP="scp -i $PEM -o StrictHostKeyChecking=no"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Dealer Addendums — Deploying to EC2                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo "  Server: $EC2_HOST"
echo "  Local:  $LOCAL_DIR"
echo ""

# ── 1. Install server dependencies ───────────────────────────────────────────
echo "→ Step 1/5: Installing server software..."
$SSH "bash -s" << 'ENDSSH'
set -e
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -q
sudo apt-get install -y -q git nginx unzip curl certbot python3-certbot-nginx

# Node.js 20
if ! command -v node &>/dev/null || [[ "$(node -v)" != v20* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "   Node $(node -v) · npm $(npm -v)"

# PM2
sudo npm install -g pm2 --silent
echo "   PM2 $(pm2 -v)"

# Deploy dir
sudo mkdir -p /var/www/dealeraddendums-platform/logs
sudo chown -R ubuntu:ubuntu /var/www/dealeraddendums-platform
ENDSSH

# ── 2. Copy files ─────────────────────────────────────────────────────────────
echo "→ Step 2/5: Copying files to server..."
rsync -az --exclude 'node_modules' --exclude '.git' --exclude 'logs' \
  -e "ssh -i $PEM -o StrictHostKeyChecking=no" \
  "$LOCAL_DIR/" "$EC2_USER@$EC2_HOST:$REMOTE_DIR/"
echo "   Files synced."

# ── 3. Install npm dependencies ───────────────────────────────────────────────
echo "→ Step 3/5: Installing app dependencies..."
$SSH "bash -s" << 'ENDSSH'
set -e
cd /var/www/dealeraddendums-platform
for app_dir in apps/*/; do
  if [ -f "$app_dir/package.json" ]; then
    echo "   $app_dir"
    (cd "$app_dir" && npm install --production --silent)
  fi
done
ENDSSH

# ── 4. Configure nginx ────────────────────────────────────────────────────────
echo "→ Step 4/5: Configuring nginx..."
$SSH "bash -s" << 'ENDSSH'
set -e
sudo cp /var/www/dealeraddendums-platform/nginx/apps.conf /etc/nginx/sites-available/dealeraddendums
sudo ln -sf /etc/nginx/sites-available/dealeraddendums /etc/nginx/sites-enabled/dealeraddendums
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
echo "   Nginx configured and running."
ENDSSH

# ── 5. Start apps with PM2 ───────────────────────────────────────────────────
echo "→ Step 5/5: Starting apps with PM2..."
$SSH "bash -s" << 'ENDSSH'
set -e
cd /var/www/dealeraddendums-platform
pm2 delete all 2>/dev/null || true
pm2 start ecosystem.config.js
pm2 save
# Auto-start PM2 on reboot
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | sudo bash
echo "   Apps running."
ENDSSH

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Deploy complete!                                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  ✓ Platform is running at: http://$EC2_HOST"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Set your Anthropic API key:"
echo "     $SSH"
echo "     pm2 set staterules:ANTHROPIC_API_KEY sk-ant-xxxx"
echo "     pm2 set homepage:ADMIN_PASSWORD yourpassword"
echo "     pm2 restart all"
echo ""
echo "  2. Point DNS:"
echo "     apps.dealeraddendums.com → $(curl -s https://checkip.amazonaws.com/ 2>/dev/null || echo '<ec2-public-ip>')"
echo ""
echo "  3. After DNS propagates, enable HTTPS:"
echo "     $SSH"
echo "     sudo certbot --nginx -d apps.dealeraddendums.com"
echo ""
echo "  App status:"
$SSH "pm2 list"
