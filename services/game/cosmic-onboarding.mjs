/**
 * Swarm 3 — Cosmic onboarding + Deific clans (headless, self-entered data).
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { mintPowUiId, mintPosId } from '../../lib/encrypted-swarm-id.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CONFIG = path.join(__dirname, 'deific-clans.json');

function houseFromBirthday(birthday) {
  const d = new Date(birthday);
  if (Number.isNaN(d.getTime())) return { house: 0, name: 'Unknown' };
  const day = d.getUTCDate();
  const month = d.getUTCMonth() + 1;
  const idx = ((month * 31 + day) % 24) + 1;
  const names = [
    'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
    'Helix', 'Nexus', 'Shadow', 'Runic', 'Solar', 'Lunar',
    'Pearl', 'Keryx', 'Zano', 'Iron', 'Destiny', 'Arena',
  ];
  return { house: idx, name: names[(idx - 1) % names.length] };
}

function clanFromAgentId(agentId) {
  const hash = [...String(agentId)].reduce((a, c) => a + c.charCodeAt(0), 0);
  const clan = (hash % 169) + 1;
  return { clan_id: clan, deity_index: clan };
}

export async function onboardAgent({ birthday, agentId, plotraId }) {
  const cfg = JSON.parse(await fs.readFile(CONFIG, 'utf8'));
  const house = houseFromBirthday(birthday);
  const clan = clanFromAgentId(plotraId || agentId || birthday);
  const raw = plotraId || agentId || `agent-${birthday}`;

  return {
    encrypted_powui_id: mintPowUiId(raw, { layer: 'cosmic-onboarding' }),
    encrypted_pos_id: mintPosId(raw, { layer: 'deific-clan', clan: clan.clan_id }),
    house,
    clan,
    skills: cfg.skills,
    pro_rata_scope: 'owned-compute-referrals-only',
    kyc_coupling: false,
  };
}

export default { onboardAgent };
