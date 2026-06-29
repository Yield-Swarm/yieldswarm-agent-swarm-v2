/**
 * YieldSwarm integration server.
 *
 * Responsibilities:
 *   1. Expose the telemetry API (/api/*) that fuses Akash worker data with
 *      on-chain telemetry (emission router, treasury splits, agent leaderboard).
 *   2. Serve the Arena dashboard and Portal frontends.
 *   3. Proxy Kairo + sovereign surfaces and resolve legacy static links.
 */

import express from 'express';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import config from './config.js';
import { startCronJobs } from './jobs/cron.js';
import apiRouter from './routes/api.js';
import kairoRouter from './routes/kairo.js';
import sovereignRouter from './routes/sovereign.js';
import helixRouter from './routes/helix.js';
import genesisRouter from './routes/genesis.js';
import swarmRouter from './routes/swarm.js';
import toolsRouter from './routes/tools.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..');
const frontendDir = path.join(repoRoot, 'frontend');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use('/api', apiRouter);
app.use('/api/kairo', kairoRouter);
app.use('/api/sovereign', sovereignRouter);
app.use('/api/helix', helixRouter);
app.use('/api/genesis', genesisRouter);
app.use('/api/swarm', swarmRouter);
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

/** Runtime config for Kairo static app (Mapbox + API base). */
app.get('/kairo-app/config.js', (_req, res) => {
  const payload = {
    apiBase: process.env.KAIRO_PUBLIC_API_BASE || '/api/kairo',
    mapboxToken:
      process.env.MAPBOX_TOKEN ||
      process.env.MAPBOX_ACCESS_TOKEN ||
      process.env.VITE_MAPBOX_TOKEN ||
      '',
  };
  res.type('application/javascript');
  res.send(`window.KAIRO_CONFIG=${JSON.stringify(payload)};`);
});

// ---- Frontends -----------------------------------------------------------
app.use('/arena', express.static(path.join(frontendDir, 'arena')));
app.use('/portal', express.static(path.join(frontendDir, 'portal')));

// Odysseus workspace shell (iframe target for Portal SSO handoff).
app.get('/odysseus', (_req, res) => {
  res.type('html').send(`<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"/><title>Odysseus Workspace</title>
<style>body{margin:0;background:#04060a;color:#d7ffe9;font-family:monospace;padding:24px}</style></head>
<body><h1>Odysseus Workspace</h1>
<p>Connect Odysseus runtime via <code>docker compose -f docker-compose.odysseus.yml up</code>.</p>
<p>Agent memory API: <code>agents/odysseus_memory.py</code></p></body></html>`);
});

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

app.get('/', (_req, res) => res.redirect('/portal/'));

app.use((_req, res) => res.status(404).json({ error: 'not found' }));

const server = app.listen(config.port, config.host, () => {
  // eslint-disable-next-line no-console
  console.log(
    `[yieldswarm] integration server listening on http://${config.host}:${config.port}\n` +
      `  Portal:  /portal/\n` +
      `  Arena:   /arena/\n` +
      `  Kairo:   /kairo/  /kairo-app/\n` +
      `  Vault:   /dashboard/sovereign-dashboard.html\n` +
      `  API:     /api/arena/overview\n` +
      `  Odysseus: /api/telemetry/odysseus  /api/brain/status\n` +
      `  Great Delta: /api/great-delta/overview\n` +
      `  Helix:     /api/helix/status  /api/helix/activate`,
  );
  if (config.cronJobsEnabled) {
    startCronJobs();
  }
});

export { app, server };
