const express = require('express');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, '../public')));

const REGISTRY_PATH = path.join(__dirname, '../apps-registry.json');
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'changeme';

// Simple token store (in-memory; restarts clear sessions — fine for internal use)
const sessions = new Set();

function getRegistry() {
  return JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
}

function saveRegistry(data) {
  fs.writeFileSync(REGISTRY_PATH, JSON.stringify(data, null, 2));
}

// ── Public: list of active apps ───────────────────────────────────────────────
app.get('/api/apps', (req, res) => {
  const reg = getRegistry();
  res.json(reg.apps.filter(a => a.status !== 'hidden'));
});

// ── Admin: login ──────────────────────────────────────────────────────────────
app.post('/api/admin/login', (req, res) => {
  const { password } = req.body;
  if (password !== ADMIN_PASSWORD) {
    return res.status(401).json({ error: 'Invalid password' });
  }
  const token = crypto.randomBytes(32).toString('hex');
  sessions.add(token);
  res.json({ token });
});

// ── Admin auth middleware ─────────────────────────────────────────────────────
function requireAdmin(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');
  if (!sessions.has(token)) return res.status(401).json({ error: 'Unauthorized' });
  next();
}

// ── Admin: get all apps (including hidden) ────────────────────────────────────
app.get('/api/admin/apps', requireAdmin, (req, res) => {
  res.json(getRegistry());
});

// ── Admin: update an app ──────────────────────────────────────────────────────
app.patch('/api/admin/apps/:slug', requireAdmin, (req, res) => {
  const reg = getRegistry();
  const idx = reg.apps.findIndex(a => a.slug === req.params.slug);
  if (idx === -1) return res.status(404).json({ error: 'App not found' });
  reg.apps[idx] = { ...reg.apps[idx], ...req.body };
  saveRegistry(reg);
  res.json(reg.apps[idx]);
});

// ── Admin: add an app entry ───────────────────────────────────────────────────
app.post('/api/admin/apps', requireAdmin, (req, res) => {
  const reg = getRegistry();
  const app_entry = { added: new Date().toISOString().split('T')[0], status: 'active', ...req.body };
  reg.apps.push(app_entry);
  saveRegistry(reg);
  res.json(app_entry);
});

// ── Admin: reorder apps ───────────────────────────────────────────────────────
app.put('/api/admin/apps/order', requireAdmin, (req, res) => {
  const { order } = req.body; // array of slugs
  const reg = getRegistry();
  reg.apps.sort((a, b) => order.indexOf(a.slug) - order.indexOf(b.slug));
  saveRegistry(reg);
  res.json({ ok: true });
});

// ── Serve SPA for all other routes ───────────────────────────────────────────
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Homepage running on port ${PORT}`));
