/**
 * Encrypted swarm identities for PoW, PoS, and PoWUI surfaces.
 * Opaque IDs — no raw wallet/hardware serials in logs or UI.
 */

import crypto from 'node:crypto';

const TYPES = Object.freeze({
  POW: 'pow',
  POS: 'pos',
  POWUI: 'powui',
});

const VERSION = 1;

function deriveKey(secret) {
  const material = secret || process.env.SWARM_ID_ENCRYPTION_KEY || process.env.AGENTSWARM_MASTER_KEY || 'yieldswarm-dev-only-change-in-prod';
  return crypto.createHash('sha256').update(`swarm-id:v${VERSION}:${material}`).digest();
}

function pack(type, plaintext) {
  const key = deriveKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const payload = Buffer.from(JSON.stringify({ t: type, p: plaintext, ts: Date.now() }), 'utf8');
  const enc = Buffer.concat([cipher.update(payload), cipher.final()]);
  const tag = cipher.getAuthTag();
  const blob = Buffer.concat([Buffer.from([VERSION]), iv, tag, enc]).toString('base64url');
  return `ys_${type}_${blob}`;
}

function unpack(token) {
  if (!token || typeof token !== 'string') throw new Error('invalid token');
  const m = token.match(/^ys_(pow|pos|powui)_([A-Za-z0-9_-]+)$/);
  if (!m) throw new Error('invalid token format');
  const type = m[1];
  const raw = Buffer.from(m[2], 'base64url');
  if (raw[0] !== VERSION) throw new Error('unsupported version');
  const iv = raw.subarray(1, 13);
  const tag = raw.subarray(13, 29);
  const enc = raw.subarray(29);
  const key = deriveKey();
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const plain = Buffer.concat([decipher.update(enc), decipher.final()]).toString('utf8');
  const data = JSON.parse(plain);
  if (data.t !== type) throw new Error('type mismatch');
  return { type, plaintext: data.p, mintedAt: data.ts };
}

export function mintPowId(rawId, meta = {}) {
  return pack(TYPES.POW, { id: rawId, ...meta });
}

export function mintPosId(rawId, meta = {}) {
  return pack(TYPES.POS, { id: rawId, ...meta });
}

export function mintPowUiId(rawId, meta = {}) {
  return pack(TYPES.POWUI, { id: rawId, ...meta });
}

export function resolveEncryptedId(token) {
  return unpack(token);
}

export function isEncryptedSwarmId(value) {
  return typeof value === 'string' && /^ys_(pow|pos|powui)_/.test(value);
}

export function redactForLogs(value) {
  if (isEncryptedSwarmId(value)) return `${value.slice(0, 12)}…`;
  if (typeof value === 'string' && value.length > 16) return `${value.slice(0, 6)}…${value.slice(-4)}`;
  return value;
}

export { TYPES };
export default { mintPowId, mintPosId, mintPowUiId, resolveEncryptedId, isEncryptedSwarmId, redactForLogs, TYPES };
