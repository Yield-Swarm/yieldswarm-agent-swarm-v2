/**
 * YieldSwarm integration server.
 *
 * Responsibilities:
 *   1. Expose the telemetry API (/api/*) that fuses Akash worker data with
 *      on-chain telemetry (emission router, treasury splits, leaderboard).
 *   2. Serve the Arena dashboard and Portal frontends.
 *   3. Resolve the previously-broken static links (/marketplace, /council/status,
 *      /sales) so navigation across the surfaces actually works.
 */

import express from 'express';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import config from './config.js';
import apiRouter from './routes/api.js';
import kairoRouter from './routes/kairo.js';
import toolsRouter from './routes/tools.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const frontendDir = path.join(repoRoot, 'frontend');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));

// Permissive CORS for read-only telemetry (dashboard may be hosted elsewhere).
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use('/api', apiRouter);
app.use('/api/kairo', kairoRouter);
app.use('/', toolsRouter);

// ---- Dashboards ($5M vault, OpenClaw admin) -------------------------------
app.use('/dashboard', express.static(path.join(repoRoot, 'dashboard')));
app.get('/vault', (_req, res) =>
  res.redirect('/dashboard/sovereign-dashboard.html'),
);
app.get('/vault-dashboard', (_req, res) =>
  res.sendFile(path.join(repoRoot, 'dashboard', 'sovereign-dashboard.html')),
);

// ---- Kairo static surfaces -------------------------------------------------
app.use('/kairo', express.static(path.join(repoRoot, 'kairo', 'dashboard')));
app.use('/kairo-app', express.static(path.join(repoRoot, 'kairo', 'frontend')));

// ---- Frontends -----------------------------------------------------------
app.use('/arena', express.static(path.join(frontendDir, 'arena')));
app.use('/portal', express.static(path.join(frontendDir, 'portal')));

// Resolve the legacy/static links that existed in the repo's HTML files.
app.use('/council', express.static(path.join(repoRoot, 'council')));
app.get('/council/status', (_req, res) =>
  res.sendFile(path.join(repoRoot, 'council', 'status.html')),
);
app.get('/sales', (_req, res) =>
  res.sendFile(path.join(repoRoot, 'redesign', 'sales-mobile.html')),
);
app.get('/marketplace', (_req, res) =>
  res.sendFile(path.join(repoRoot, 'redesign', 'marketplace-exciting.html')),
);

// Root -> Portal hub.
app.get('/', (_req, res) => res.redirect('/portal/'));

app.use((_req, res) => res.status(404).json({ error: 'not found' }));

const server = app.listen(config.port, config.host, () => {
  // eslint-disable-next-line no-console
  console.log(
    `[yieldswarm] integration server listening on http://${config.host}:${config.port}\n` +
      `  Portal:  /portal/\n` +
      `  Arena:   /arena/\n` +
      `  Vault:   /dashboard/sovereign-dashboard.html\n` +
      `  API:     /api/arena/overview\n` +
      `  Odysseus: /api/telemetry/odysseus  /api/brain/status\n` +
      `  Kairo:   /kairo-app/  /api/kairo/*`,
  );
});

export { app, server };
