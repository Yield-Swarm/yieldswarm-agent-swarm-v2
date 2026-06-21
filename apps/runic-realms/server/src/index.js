import crypto from 'node:crypto';
import express from 'express';
import http from 'node:http';
import { attachGameWebSocket, getSession } from './ws/handler.js';
import { RUNE_TOKEN } from './game/compute.js';
import { CLASSES } from './game/classes.js';

const PORT = Number(process.env.RUNIC_REALMS_PORT || 8099);

const app = express();
app.disable('x-powered-by');
app.use(express.json());

app.get('/health', (_req, res) => {
  res.json({ ok: true, game: 'runic-realms', version: '0.1.0' });
});

app.get('/api/meta', (_req, res) => {
  res.json({
    token: RUNE_TOKEN,
    classes: CLASSES,
    chains: ['runic', 'apollo_nexus', 'helix', 'shadow', 'codex', 'rosetta', 'odysseus'],
  });
});

/** Leaderboard stub — top performers earn RUNE payouts */
app.get('/api/leaderboard', (_req, res) => {
  res.json({
    season: 'genesis',
    payouts: { first: 1000, second: 500, third: 250, unit: 'RUNE' },
    entries: [
      { rank: 1, name: 'Baris', rune: 42.5, floor: 7 },
      { rank: 2, name: 'Nico', rune: 38.1, floor: 6 },
      { rank: 3, name: 'WraithSlayer', rune: 31.0, floor: 5 },
    ],
  });
});

app.get('/api/player/:telegramId', (req, res) => {
  const session = getSession(req.params.telegramId);
  if (!session) return res.status(404).json({ error: 'not_found' });
  res.json({ character: session.character, dungeonFloor: session.dungeon?.floor });
});

/** Validate Telegram WebApp initData (HMAC-SHA256) */
app.post('/api/telegram/auth', (req, res) => {
  const { initData } = req.body || {};
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  if (!botToken || !initData) {
    return res.json({ ok: true, simulated: true, user: { id: 'dev', first_name: 'Baris' } });
  }
  const valid = verifyTelegramInitData(initData, botToken);
  if (!valid) return res.status(401).json({ ok: false, error: 'invalid_init_data' });
  res.json({ ok: true, user: valid.user });
});

function verifyTelegramInitData(initData, botToken) {
  const params = new URLSearchParams(initData);
  const hash = params.get('hash');
  if (!hash) return null;
  params.delete('hash');
  const dataCheckString = [...params.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join('\n');
  const secret = crypto.createHmac('sha256', 'WebAppData').update(botToken).digest();
  const computed = crypto.createHmac('sha256', secret).update(dataCheckString).digest('hex');
  if (computed !== hash) return null;
  const user = params.get('user') ? JSON.parse(params.get('user')) : null;
  return { user };
}

const server = http.createServer(app);
attachGameWebSocket(server);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[runic-realms] http://0.0.0.0:${PORT}  ws://0.0.0.0:${PORT}/ws`);
});
