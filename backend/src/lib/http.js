/**
 * Minimal HTTP helpers built on Node's global fetch (Node >= 18).
 * All upstream calls go through fetchJson so they share a timeout and
 * consistent error shape, which keeps adapter code small and predictable.
 */

import config from '../config.js';

export class UpstreamError extends Error {
  constructor(message, { status, cause } = {}) {
    super(message);
    this.name = 'UpstreamError';
    this.status = status;
    if (cause) this.cause = cause;
  }
}

export async function fetchJson(url, options = {}) {
  const { timeoutMs = config.upstreamTimeoutMs, ...rest } = options;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      ...rest,
      signal: controller.signal,
      headers: { accept: 'application/json', ...(rest.headers || {}) },
    });
    if (!res.ok) {
      throw new UpstreamError(`HTTP ${res.status} from ${url}`, { status: res.status });
    }
    return await res.json();
  } catch (err) {
    if (err instanceof UpstreamError) throw err;
    if (err.name === 'AbortError') {
      throw new UpstreamError(`Timeout after ${timeoutMs}ms calling ${url}`, { cause: err });
    }
    throw new UpstreamError(`Request failed for ${url}: ${err.message}`, { cause: err });
  } finally {
    clearTimeout(timer);
  }
}

export async function rpc(url, method, params = [], options = {}) {
  const body = JSON.stringify({ jsonrpc: '2.0', id: 1, method, params });
  const data = await fetchJson(url, {
    ...options,
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    body,
  });
  if (data.error) {
    throw new UpstreamError(`RPC ${method} error: ${data.error.message || JSON.stringify(data.error)}`);
  }
  return data.result;
}
