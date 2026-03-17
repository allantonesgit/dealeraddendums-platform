#!/bin/bash
# bootstrap.sh — Run once on a fresh Ubuntu EC2 to set up the entire platform
# Usage: bash scripts/bootstrap.sh
# Or remotely: curl -fsSL https://raw.githubusercontent.com/YOUR_GH_USER/dealeraddendums-platform/main/scripts/bootstrap.sh | bash

set -e
REPO="https://github.com/YOUR_GH_USER/dealeraddendums-platform.git"
DEPLOY_DIR="/var/www/dealeraddendums-platform"
DOMAIN="apps.dealeraddendums.com"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Dealer Addendums Platform — Bootstrap              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. System packages ────────────────────────────────────────────────────────
echo "→ Updating system packages..."
sudo apt-get update -q
sudo apt-get install -y -q git nginx unzip curl

# ── 2. Node.js 20 ─────────────────────────────────────────────────────────────
echo "→ Installing Node.js 20..."
if ! command -v node &>/dev/null || [[ $(node -v) != v20* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
echo "   Node $(node -v) · npm $(npm -v)"

# ── 3. PM2 ────────────────────────────────────────────────────────────────────
echo "→ Installing PM2..."
sudo npm install -g pm2
pm2 startup systemd -u ubuntu --hp /home/ubuntu | tail -1 | sudo bash || true

# ── 4. Clone repo ─────────────────────────────────────────────────────────────
echo "→ Cloning repository..."
sudo mkdir -p $DEPLOY_DIR
sudo chown ubuntu:ubuntu $DEPLOY_DIR
if [ -d "$DEPLOY_DIR/.git" ]; then
  echo "   Repo already exists, pulling latest..."
  cd $DEPLOY_DIR && git pull
else
  git clone $REPO $DEPLOY_DIR
fi
cd $DEPLOY_DIR

# ── 5. Install dependencies ───────────────────────────────────────────────────
echo "→ Installing app dependencies..."
mkdir -p logs
for app_dir in apps/*/; do
  if [ -f "$app_dir/package.json" ]; then
    echo "   Installing: $app_dir"
    (cd "$app_dir" && npm install --production)
  fi
done

# ── 6. Set up nginx ───────────────────────────────────────────────────────────
echo "→ Configuring nginx..."
sudo cp nginx/apps.conf /etc/nginx/sites-available/dealeraddendums
sudo ln -sf /etc/nginx/sites-available/dealeraddendums /etc/nginx/sites-enabled/dealeraddendums
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# ── 7. Start apps with PM2 ───────────────────────────────────────────────────
echo "→ Starting apps with PM2..."
pm2 start ecosystem.config.js
pm2 save

# ── 8. SSL certificate ────────────────────────────────────────────────────────
echo "→ Installing Certbot for HTTPS..."
sudo apt-get install -y -q certbot python3-certbot-nginx
echo ""
echo "   Run this to enable HTTPS (after DNS is pointed to this server):"
echo "   sudo certbot --nginx -d $DOMAIN"
echo ""

# ── Done ──────────────────────────────────────────────────────────────────────
SERVER_IP=$(curl -s ifconfig.me)
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Bootstrap complete!                                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "   Server IP:  $SERVER_IP"
echo "   Point DNS:  apps.dealeraddendums.com → $SERVER_IP"
echo ""
echo "   ⚠  Set your API keys:"
echo "   pm2 set staterules:ANTHROPIC_API_KEY sk-ant-xxxx"
echo "   pm2 set homepage:ADMIN_PASSWORD yourpassword"
echo "   pm2 restart all"
echo ""
echo "   View logs:  pm2 logs"
echo "   App status: pm2 status"
