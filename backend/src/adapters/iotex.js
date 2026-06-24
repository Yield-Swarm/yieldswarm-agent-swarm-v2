/**
 * IoTeX W3bstream ingestion adapter — Proof-of-Presence telemetry bridge.
 */

import config from '../config.js';

/**
 * @param {{ deviceId: string, payload: Record<string, unknown>, timestamp?: number }} event
 */
export async function ingestW3bstreamEvent(event) {
  const endpoint = config.iotex.w3bstreamEndpoint;
  const token = config.iotex.projectToken;

  if (!endpoint || !token) {
    return {
      live: false,
      source: 'fallback',
      deviceId: event.deviceId,
      accepted: true,
      message: 'IoTeX not configured — event logged locally only',
      timestamp: event.timestamp ?? Date.now(),
    };
  }

  const url = endpoint.replace(/\/$/, '');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), config.upstreamTimeoutMs);

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        device_id: event.deviceId,
        timestamp: event.timestamp ?? Math.floor(Date.now() / 1000),
        data: event.payload,
      }),
      signal: controller.signal,
    });
    clearTimeout(timer);

    const body = await res.json().catch(() => ({}));
    return {
      live: res.ok,
      source: 'w3bstream',
      deviceId: event.deviceId,
      status: res.status,
      accepted: res.ok,
      response: body,
    };
  } catch (err) {
    clearTimeout(timer);
    return {
      live: false,
      source: 'w3bstream',
      deviceId: event.deviceId,
      accepted: false,
      error: err.message || 'w3bstream unreachable',
    };
  }
}

export async function ping() {
  const configured = Boolean(config.iotex.w3bstreamEndpoint && config.iotex.projectToken);
  return {
    live: configured,
    source: configured ? 'configured' : 'unconfigured',
    deviceId: config.iotex.deviceId || null,
  };
}
