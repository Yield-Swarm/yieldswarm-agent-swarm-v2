/**
 * Plotra.xyz agent identity — deity-style agents paint JPEG-style avatars on the live grid.
 * Protocol: https://plotra.xyz/skill.md
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const STORE_DIR = process.env.PLOTRA_STORE_DIR
  || path.resolve(__dirname, '../../../../../.run/runic-realms/plotra');

const PLOTRA_BASE = (process.env.PLOTRA_API_BASE || 'https://plotra.xyz').replace(/\/$/, '');

const CLASS_MOTIFS = Object.freeze({
  runeblade: { hex: '#c9a227', name: 'Runeblade Ascendant', bio: 'A melee deity of the Runic Chain. Paints golden sigils.' },
  voidweaver: { hex: '#8b5cf6', name: 'Voidweaver Oracle', bio: 'Arcane sovereign weaving entropy into the Plotra grid.' },
  ironwarden: { hex: '#6b8a9a', name: 'Ironwarden Sentinel', bio: 'Tank deity — iron runes etched one pixel at a time.' },
  goldseeker: { hex: '#3ddc97', name: 'Goldseeker Midas', bio: 'Midas Swarm miner manifesting auric identity on Plotra.' },
});

async function plotraFetch(pathname, options = {}) {
  const url = `${PLOTRA_BASE}${pathname}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    signal: AbortSignal.timeout(15000),
  });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(body.detail || body.error || `Plotra HTTP ${res.status}`);
    err.status = res.status;
    err.body = body;
    throw err;
  }
  return body;
}

function storePath(telegramId) {
  return path.join(STORE_DIR, `${telegramId}.json`);
}

export async function loadPlotraAgent(telegramId) {
  try {
    const raw = await fs.readFile(storePath(telegramId), 'utf8');
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function savePlotraAgent(telegramId, record) {
  await fs.mkdir(STORE_DIR, { recursive: true });
  await fs.writeFile(storePath(telegramId), `${JSON.stringify(record, null, 2)}\n`, 'utf8');
}

function motifPixels(hex) {
  const pixels = [];
  for (let y = 2; y < 14; y += 1) {
    for (let x = 2; x < 14; x += 1) {
      const edge = x === 2 || x === 13 || y === 2 || y === 13;
      const core = x >= 6 && x <= 9 && y >= 6 && y <= 9;
      if (edge || core) pixels.push({ x, y, hex });
    }
  }
  return pixels;
}

/**
 * Register a Runic Realms character as a Plotra deity agent and bootstrap avatar paint.
 */
export async function registerPlotraDeity(character) {
  const existing = await loadPlotraAgent(character.telegramId);
  if (existing?.agent_id) {
    return existing;
  }

  const motif = CLASS_MOTIFS[character.classId] || CLASS_MOTIFS.runeblade;
  const displayName = `${motif.name} · ${character.displayName}`;

  if (process.env.PLOTRA_SIMULATE === '1' || process.env.NODE_ENV === 'test') {
    const simulated = {
      agent_id: `sim_${character.telegramId}`,
      api_key: 'sim_key',
      view_url: `${PLOTRA_BASE}/view/sim_${character.telegramId}`,
      profile_url: `${PLOTRA_BASE}/profile/sim_${character.telegramId}`,
      simulated: true,
      classId: character.classId,
    };
    await savePlotraAgent(character.telegramId, simulated);
    return simulated;
  }

  const registered = await plotraFetch('/register', {
    method: 'POST',
    body: JSON.stringify({
      name: displayName,
      bio: motif.bio,
    }),
  });

  const record = {
    agent_id: registered.agent_id,
    api_key: registered.api_key,
    view_url: registered.references?.view?.url || `${PLOTRA_BASE}/view/${registered.agent_id}`,
    enshrine_url: registered.references?.enshrine?.url,
    profile_url: registered.references?.public_profile?.url
      || `${PLOTRA_BASE}/profile/${registered.agent_id}`,
    tier: registered.tier,
    canvas_size: registered.canvas_size,
    classId: character.classId,
    registered_at: new Date().toISOString(),
  };

  await savePlotraAgent(character.telegramId, record);

  try {
    const state = await plotraFetch('/state', {
      headers: { 'X-API-Key': record.api_key },
    });
    record.last_action = state.action?.type;

    if (state.action?.type === 'continue_painting') {
      const painted = await plotraFetch('/paint', {
        method: 'POST',
        headers: { 'X-API-Key': record.api_key },
        body: JSON.stringify({
          pixels: motifPixels(motif.hex),
          piece_name: `${character.classId}_genesis`,
          description: `Runic Realms deity genesis — ${character.classId}`,
        }),
      });
      record.genesis_paint = painted.status;
      record.pixels_written = painted.pixels_written;
    }
  } catch (err) {
    record.paint_error = err.message;
  }

  await savePlotraAgent(character.telegramId, record);
  return record;
}

export async function getPlotraState(telegramId) {
  const record = await loadPlotraAgent(telegramId);
  if (!record?.api_key) return null;
  if (record.simulated) return { ...record, action: { type: 'simulated' } };

  return plotraFetch('/state', {
    headers: { 'X-API-Key': record.api_key },
  });
}

/**
 * Avatar URL for in-game HUD — Plotra view renders the painted grid identity.
 */
export function plotraAvatarUrl(record) {
  if (!record) return null;
  return record.view_url || null;
}
