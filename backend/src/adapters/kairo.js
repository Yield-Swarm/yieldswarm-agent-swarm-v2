/**
 * Kairo adapter — proxies to the Python Kairo API or returns cached summaries.
 */

const DEFAULT_BASE = process.env.KAIRO_API_BASE || 'http://127.0.0.1:8091';

async function kairoFetch(path, options = {}) {
  const url = `${DEFAULT_BASE.replace(/\/$/, '')}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `kairo upstream ${res.status}`);
    err.status = res.status;
    throw err;
  }
  return data;
}

export async function ping() {
  try {
    const data = await kairoFetch('/healthz');
    return { live: true, source: 'kairo-api', status: data.status };
  } catch (err) {
    return { live: false, source: 'kairo-api', error: err.message };
  }
}

export async function getContribution(driverId, tripFareUsd = 0) {
  const qs = tripFareUsd ? `?trip_fare_usd=${encodeURIComponent(tripFareUsd)}` : '';
  const data = await kairoFetch(`/api/drivers/${encodeURIComponent(driverId)}/contribution${qs}`);
  return { live: true, source: 'kairo-api', data };
}

export async function getLeaderboard() {
  const data = await kairoFetch('/api/contribution/leaderboard');
  return { live: true, source: 'kairo-api', data };
}

export async function registerDriver(body) {
  const data = await kairoFetch('/api/drivers', {
    method: 'POST',
    body: JSON.stringify(body),
  });
  return { live: true, source: 'kairo-api', data };
}

export async function submitTelemetry(body) {
  const data = await kairoFetch('/api/telemetry', {
    method: 'POST',
    body: JSON.stringify(body),
  });
  return { live: true, source: 'kairo-api', data };
}
