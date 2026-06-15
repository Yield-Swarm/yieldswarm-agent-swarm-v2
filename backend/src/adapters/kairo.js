/**
 * Kairo telemetry adapter — proxies to the Kairo FastAPI service.
 */

import config from '../config.js';
import { fetchJson } from '../lib/http.js';

const KAIRO_API = config.kairoApiUrl;

export async function getDashboardSummary() {
  try {
    const data = await fetchJson(`${KAIRO_API}/dashboard/summary`);
    return { live: true, source: 'kairo-api', ...data };
  } catch (err) {
    return {
      live: false,
      source: 'fallback',
      driver_count: 0,
      total_potential_reward_usd: 0,
      drivers: [],
      error: err.message,
    };
  }
}

export async function getDriverContribution(driverId) {
  try {
    const data = await fetchJson(`${KAIRO_API}/drivers/${driverId}`);
    return { live: true, source: 'kairo-api', ...data };
  } catch (err) {
    return { live: false, source: 'fallback', error: err.message };
  }
}
