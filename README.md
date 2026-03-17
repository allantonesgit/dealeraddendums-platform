# Dealer Addendums Platform

Internal tools and customer-facing apps hosted at `apps.dealeraddendums.com`.

## Structure

```
dealeraddendums-platform/
├── apps/
│   ├── homepage/        # Navigation hub + admin panel (apps.dealeraddendums.com)
│   ├── staterules/      # State dealer addendum rules lookup (apps.dealeraddendums.com/staterules)
│   └── [new-app]/       # Add future apps here
├── nginx/
│   └── apps.conf        # Nginx config — routes traffic to each app
├── scripts/
│   ├── bootstrap.sh     # Run once on fresh EC2 to install everything
│   ├── deploy.sh        # Pull latest from GitHub + restart apps
│   └── add-app.sh       # Scaffold a new app
└── shared/
    └── middleware.js     # Shared Express middleware (logging, auth helpers)
```

## Deploying a fresh server

```bash
# 1. SSH into your EC2
ssh -i ~/ssh/QuietReady2026.pem ubuntu@<your-new-ec2-ip>

# 2. Run bootstrap (installs Node, nginx, PM2, clones repo, starts everything)
curl -fsSL https://raw.githubusercontent.com/<YOUR_GH_USER>/dealeraddendums-platform/main/scripts/bootstrap.sh | bash

# 3. Set secrets
pm2 set dealer-platform:ANTHROPIC_API_KEY sk-ant-xxxx
pm2 set dealer-platform:ADMIN_PASSWORD yourpassword

# 4. Point apps.dealeraddendums.com DNS A record to this server's IP
```

## Adding a new app

```bash
bash scripts/add-app.sh myappname "My App Display Name" 3002
```

This scaffolds the app, adds it to PM2, nginx, and the homepage nav automatically.

## Deploying updates

```bash
bash scripts/deploy.sh
```

## Local development

```bash
cd apps/staterules && npm install && npm run dev
```
