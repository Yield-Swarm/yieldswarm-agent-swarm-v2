/**
 * Swarm 1 — Physical core telemetry (solar ranch, ASICs, Tesla fleet).
 * Owned hardware only — no free-credit cloud mining paths.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { mintPowId, mintPowUiId, redactForLogs } from '../../lib/encrypted-swarm-id.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');
const RUN_DIR = process.env.RUN_DIR || path.join(REPO_ROOT, '.run');

const DEFAULTS = {
  solarKw: Number(process.env.SOLAR_RANCH_KW || 27),
  asicCount: Number(process.env.ASIC_Z15_COUNT || 0),
  vehicleId: process.env.VEHICLE_ID || 'APOLLO_NEXUS_TEST_01',
};

export async function ingestPhysicalTelemetry(payload = {}) {
  const now = new Date().toISOString();
  const deviceRaw = payload.device_id || payload.deviceId || `solar-ranch-${DEFAULTS.solarKw}kw`;
  const powId = mintPowId(deviceRaw, { layer: 'physical', kind: payload.kind || 'solar' });
  const uiId = mintPowUiId(deviceRaw, { surface: 'telemetry-dashboard' });

  const record = {
    received_at: now,
    encrypted_pow_id: powId,
    encrypted_powui_id: uiId,
    device_redacted: redactForLogs(deviceRaw),
    solar_kw: payload.solar_kw ?? DEFAULTS.solarKw,
    asic_units: payload.asic_count ?? DEFAULTS.asicCount,
    tesla_vehicle: payload.vehicle_id ?? DEFAULTS.vehicleId,
    starlink_online: payload.starlink_online ?? null,
    tokens_per_sec: payload.tokens_per_sec ?? null,
    temp_c: payload.temp_c ?? null,
    source: payload.source || 'owned-hardware',
    ethical_scope: 'paid-akash-and-owned-hardware-only',
  };

  await fs.mkdir(RUN_DIR, { recursive: true });
  const out = path.join(RUN_DIR, 'physical-telemetry-last.json');
  await fs.writeFile(out, `${JSON.stringify(record, null, 2)}\n`);
  return record;
}

export async function getPhysicalTelemetryStatus() {
  try {
    const raw = await fs.readFile(path.join(RUN_DIR, 'physical-telemetry-last.json'), 'utf8');
    return JSON.parse(raw);
  } catch {
    return { status: 'idle', solar_kw: DEFAULTS.solarKw, asic_units: DEFAULTS.asicCount };
  }
}
