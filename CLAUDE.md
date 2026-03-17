# CLAUDE.md — Dealer Addendums Platform

This file gives Claude full context about this project. Read it at the start of every session before writing any code or making any changes.

---

## Who I Am

**Allan Tone** — owner of Dealer Addendums, a company serving the car dealership industry. I am not a developer. I rely on Claude to build and maintain all code. Keep explanations clear and commands copy-paste ready.

---

## What This Platform Is

A collection of small internal tools and customer-facing web apps for the dealership industry, all hosted under one domain and managed from one codebase.

**Live URL:** `apps.dealeraddendums.com`
**Homepage:** Navigation hub listing all apps + password-protected admin panel

---

## Infrastructure

| Item | Detail |
|---|---|
| Server | AWS EC2 — Ubuntu 24.04 |
| Server IP | 54.89.142.76 |
| SSH command | `ssh -i /Users/allantone/ssh/DA2026.pem ubuntu@ec2-54-89-142-76.compute-1.amazonaws.com` |
| PEM key location | `/Users/allantone/ssh/DA2026.pem` |
| Deploy directory | `/var/www/dealeraddendums-platform` |
| Local files | `/Users/allantone/Sites/dealeraddendums-platform` |
| GitHub repo | `https://github.com/allantonesgit/dealeraddendums-platform` |
| Web server | nginx (reverse proxy) |
| Process manager | PM2 (keeps apps running, auto-restarts on crash) |
| Node version | v20 |

---

## Monorepo Structure

```
dealeraddendums-platform/
├── CLAUDE.md                      ← You are here
├── README.md                      ← Developer quickstart
├── package.json                   ← Root package (npm workspaces)
├── ecosystem.config.js            ← PM2 config — defines all running apps
├── .github/
│   └── workflows/
│       └── deploy.yml             ← Auto-deploy on git push to main
├── nginx/
│   └── apps.conf                  ← Nginx routing — one location block per app
├── scripts/
│   ├── mac-deploy.sh              ← Full deploy from Mac to EC2 (run once on new server)
│   ├── sync.sh                    ← Push local changes to EC2 quickly (day-to-day)
│   ├── deploy.sh                  ← Run on server: git pull + restart
│   └── add-app.sh                 ← Scaffold a new app + wire into nginx + PM2
├── apps/
│   ├── homepage/                  ← Port 3000 — nav hub + admin panel
│   │   ├── apps-registry.json     ← Source of truth: list of all apps
│   │   ├── package.json
│   │   ├── server/index.js        ← Express server + admin API
│   │   └── public/index.html      ← Frontend SPA (public nav + admin panel)
│   └── staterules/                ← Port 3001 — State addendum rules lookup
│       ├── package.json
│       ├── server/index.js        ← Express server + Anthropic API proxy
│       └── public/index.html      ← Frontend
└── shared/
    └── middleware.js              ← Shared Express middleware (future use)
```

---

## How Routing Works

nginx listens on port 80 (and 443 after SSL) and routes traffic by URL path to the correct Node app:

```
apps.dealeraddendums.com/           → homepage app  (port 3000)
apps.dealeraddendums.com/staterules → staterules app (port 3001)
apps.dealeraddendums.com/myapp      → myapp          (port 3002)
```

Each app is a standalone Express server. Apps never talk to each other directly — all communication goes through the browser.

---

## Apps Registry

`apps/homepage/apps-registry.json` is the single source of truth for what apps exist. The homepage reads this file to build the navigation cards. The admin panel writes to it when you add/edit apps.

```json
{
  "platform": "Dealer Addendums",
  "domain": "apps.dealeraddendums.com",
  "apps": [
    {
      "slug": "staterules",
      "name": "State Addendum Rules",
      "description": "Look up new vehicle pricing addendum regulations by state",
      "port": 3001,
      "status": "active",
      "added": "2025-03-17",
      "icon": "📋"
    }
  ]
}
```

App status options: `active`, `beta`, `hidden`

---

## Existing Apps

### 1. Homepage (`apps/homepage/`) — Port 3000

**URL:** `apps.dealeraddendums.com`

**What it does:**
- Public-facing navigation page showing cards for all active apps
- Password-protected admin panel (click "Admin" in the header)

**Admin panel features:**
- Dashboard with app count stats
- Apps table — view all apps, edit name/description/icon/status
- Add new app entries to the registry
- Settings page with server command reference

**How auth works:**
- Simple password check against `ADMIN_PASSWORD` environment variable
- On success, returns a random session token stored in `sessionStorage`
- No database — sessions clear when browser tab closes
- Set password with: `pm2 set homepage:ADMIN_PASSWORD yourpassword`

**Key files:**
- `server/index.js` — Express server, serves static files, provides `/api/apps` (public) and `/api/admin/*` (protected) endpoints
- `public/index.html` — Single-page app, two views: `home` and `admin`, toggled with JS
- `apps-registry.json` — Read/written by the server

---

### 2. State Addendum Rules (`apps/staterules/`) — Port 3001

**URL:** `apps.dealeraddendums.com/staterules`

**What it does:**
Allows users (customers and internal team) to select any U.S. state and get an AI-generated summary of that state's laws and regulations around new vehicle pricing addendums at car dealerships — including window sticker rules, doc fee caps, market adjustment legality, advertising rules, and key statutes.

**How it works:**
1. User selects a state from a dropdown
2. Browser sends a POST to `/staterules/api/lookup` with `{ state: "Maryland" }`
3. The Express server receives it, adds the Anthropic API key from environment, and calls `api.anthropic.com/v1/messages`
4. The Anthropic API uses web search to find current regulations, streams the response back
5. The server pipes the SSE stream back to the browser
6. The browser renders the HTML response chunk by chunk as it arrives
7. User can export results as a `.txt` file

**Why the API call is on the server (not the browser):**
The Anthropic API key must stay secret. The browser never sees it — it only calls `/staterules/api/lookup` on our own server.

**AI model used:** `claude-sonnet-4-20250514`

**Tools used:** `web_search_20250305` — allows Claude to search for current state laws rather than relying on training data

**Set API key with:** `pm2 set staterules:ANTHROPIC_API_KEY sk-ant-xxxx`

**Key files:**
- `server/index.js` — Express server, mounts static files at `/staterules`, handles `/staterules/api/lookup`, proxies streaming response from Anthropic
- `public/index.html` — Frontend with state dropdown, streaming result display, formatted HTML output, export button

**Design:** Navy/gold color scheme, Playfair Display + DM Sans fonts, result sections numbered with circular badges, callout boxes for key rules, warning callout for legal disclaimer

---

## PM2 — Process Management

PM2 keeps all apps running. Key commands (run on the server after SSH):

```bash
pm2 list                          # See all running apps and their status
pm2 logs                          # Live logs from all apps
pm2 logs staterules               # Logs for one app
pm2 restart all                   # Restart everything
pm2 restart staterules            # Restart one app
pm2 reload ecosystem.config.js    # Reload config (zero downtime)
pm2 set staterules:ANTHROPIC_API_KEY sk-ant-xxx   # Set env var
pm2 set homepage:ADMIN_PASSWORD yourpassword       # Set env var
```

---

## Day-to-Day Workflow

### Making changes to an existing app
1. Edit files in `/Users/allantone/Sites/dealeraddendums-platform/`
2. Run `bash scripts/sync.sh` from that directory
3. Changes are live in ~10 seconds

### Adding a brand new app
1. Tell Claude what the app should do
2. Claude builds all the files in `apps/newappname/`
3. Update `ecosystem.config.js` — add a new PM2 entry
4. Update `nginx/apps.conf` — add a new location block
5. Update `apps/homepage/apps-registry.json` — add the app entry
6. Run `bash scripts/sync.sh`
7. SSH into server and run: `pm2 start ecosystem.config.js --only newappname`

### Deploying from GitHub (after git push)
The GitHub Action in `.github/workflows/deploy.yml` auto-deploys on every push to `main`. Requires two GitHub secrets set in the repo settings:
- `EC2_HOST` = `54.89.142.76`
- `EC2_SSH_KEY` = contents of `DA2026.pem`

---

## Conventions & Standards

**Ports:** Homepage = 3000, staterules = 3001. Each new app gets the next available port (3002, 3003, etc.)

**URL paths:** Always match the app slug. App slug `vinlookup` → served at `/vinlookup` → port 3002.

**Static files:** Each app serves its own `public/` folder under its own path prefix (e.g. `app.use('/staterules', express.static(...))`).

**API routes:** Each app's API routes are prefixed with its slug (e.g. `/staterules/api/lookup`) so nginx can route them correctly.

**Environment variables:** Always set via PM2 (`pm2 set appname:VAR_NAME value`), never hardcoded in files.

**Styling:** Navy (`#0f2744`) and gold (`#c9963a`) color scheme. Fonts: Playfair Display (headings) + DM Sans (body). Keep consistent with existing apps.

**No frameworks:** Plain HTML/CSS/JS for frontends. Express only for servers. No React, no build steps — keeps things simple and deployable without a build pipeline.

**Error handling:** All server API routes should catch errors and return JSON `{ error: "message" }`. Frontends should show a visible error state, never a blank screen.

---

## SSL / HTTPS

Not yet enabled. To enable after DNS is confirmed pointing to the server:

```bash
ssh -i /Users/allantone/ssh/DA2026.pem ubuntu@ec2-54-89-142-76.compute-1.amazonaws.com
sudo certbot --nginx -d apps.dealeraddendums.com
```

Then uncomment the HTTPS block in `nginx/apps.conf`.

---

## What Claude Should Do at the Start of Each Session

1. Read this file fully
2. Ask what app or change is needed
3. Build files locally in `/Users/allantone/Sites/dealeraddendums-platform/apps/newapp/`
4. Provide the exact sync/deploy commands to get it live
5. Never assume Allan has development experience — always give complete, copy-paste-ready instructions
