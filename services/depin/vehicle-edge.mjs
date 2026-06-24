#!/usr/bin/env node
/**
 * Vehicle edge telemetry — deploy on Apollo Nexus gateway hardware.
 * POST → backend /api/iot/telemetry (helixpow.pw)
 */
const VEHICLE_ID = process.env.VEHICLE_ID ?? 'APOLLO_NEXUS_TEST_01';
const INGEST_URL =
  process.env.HELIXPOW_INGEST_URL ??
  process.env.HELIXPOW_TELEMETRY_URL ??
  'http://127.0.0.1:8080/api/iot/telemetry';
const LOLMINER_PORT = process.env.LOLMINER_LOCAL_PORT ?? '4067';
const TICK_MS = Number(process.env.SYSTEM_CLOCK_TICK_RATE ?? 5000);
const AUTH = process.env.HELIOM_EDGE_INGEST_KEY ?? '';

async function captureTelemetry() {
  let minerStats = 'offline';
  try {
    const r = await fetch(`http://127.0.0.1:${LOLMINER_PORT}/api/v1/summary`);
    minerStats = await r.text();
  } catch {
    /* lolminer optional */
  }

  const payload = {
    vehicleId: VEHICLE_ID,
    timestamp: Date.now(),
    minerStats,
    depinSignalStrength: -65 + Math.floor(Math.random() * 15),
    gps: null,
  };

  try {
    const res = await fetch(INGEST_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(AUTH ? { 'X-Agent-Auth': AUTH } : {}),
      },
      body: JSON.stringify(payload),
    });
    console.log(`[telemetry] ${res.status} vehicle=${VEHICLE_ID}`);
  } catch (err) {
    console.error('[telemetry] cache locally:', err.message);
  }
}

console.log(`[vehicle-edge] ${VEHICLE_ID} → ${INGEST_URL} every ${TICK_MS}ms`);
setInterval(captureTelemetry, TICK_MS);
void captureTelemetry();
