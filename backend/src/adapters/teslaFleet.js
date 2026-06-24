/**
 * Tesla Fleet API telemetry → TeslaMeshEntropyCore (pillar 7).
 */
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const require = createRequire(import.meta.url);
const { TeslaMeshEntropyCore } = require(
  path.join(repoRoot, 'src', 'infrastructure', 'entropy-core.js'),
);

const mesh = new TeslaMeshEntropyCore();

const CRITICAL_BATTERY = Number(process.env.TESLA_MIN_BATTERY_PCT ?? 20);
const MAX_CABIN_TEMP_C = Number(process.env.TESLA_MAX_CABIN_TEMP_C ?? 55);

/**
 * @param {{ vin?: string, telemetry_data?: Record<string, unknown> } & Record<string, unknown>} body
 */
export function ingestTeslaFleetTelemetry(body = {}) {
  const vin = body.vin || body.vehicle_id;
  if (!vin) {
    return { ok: false, error: 'MISSING_VIN', note: 'Provide vin or vehicle_id' };
  }

  const telemetry = body.telemetry_data || body.telemetry || body;
  const battery = Number(telemetry.battery_level ?? telemetry.soc ?? 100);
  const cabinTemp = Number(telemetry.cabin_temperature ?? telemetry.inside_temp ?? 0);

  if (battery < CRITICAL_BATTERY) {
    return {
      ok: false,
      error: 'LOW_BATTERY_RESERVE',
      battery,
      threshold: CRITICAL_BATTERY,
      action: 'DISCONNECT_FROM_MESH',
    };
  }

  if (cabinTemp > MAX_CABIN_TEMP_C) {
    return {
      ok: false,
      error: 'THERMAL_CHASSIS_OVERLOAD',
      cabinTemp,
      threshold: MAX_CABIN_TEMP_C,
      action: 'THROTTLE_EDGE_INFERENCE',
    };
  }

  const result = mesh.ingestFleetTelemetry(String(vin), telemetry);
  if (!result) {
    return { ok: false, error: 'INGEST_REJECTED', note: 'battery_level required in telemetry' };
  }

  return {
    ok: true,
    pillar: 7,
    pillarKey: 'tesla_fleet',
    ...result,
    safety: { battery, cabinTemp, withinLimits: true },
  };
}

export function getTeslaMeshStatus() {
  return {
    configured: Boolean(process.env.TESLA_CLIENT_ID),
    activeNodes: mesh.fleetNodes?.size ?? 0,
    resonanceTargetHz: mesh.resonanceTarget,
    limits: { minBatteryPct: CRITICAL_BATTERY, maxCabinTempC: MAX_CABIN_TEMP_C },
  };
}
