/**
 * Axios HTTP client with retries, timeouts, and consistent errors.
 * Use for upstream telemetry, sovereign overlays, and payment webhooks.
 */

import axios from 'axios';
import config from '../config.js';

export class UpstreamError extends Error {
  constructor(message, { status, cause } = {}) {
    super(message);
    this.name = 'UpstreamError';
    this.status = status;
    if (cause) this.cause = cause;
  }
}

const client = axios.create({
  timeout: config.upstreamTimeoutMs,
  headers: { accept: 'application/json' },
  validateStatus: (s) => s >= 200 && s < 300,
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * GET/POST JSON with retries and timeout.
 * @param {import('axios').AxiosRequestConfig} options
 * @param {{ retries?: number, retryDelayMs?: number }} retry
 */
export async function requestJson(options, retry = {}) {
  const retries = retry.retries ?? config.httpRetries ?? 2;
  const retryDelayMs = retry.retryDelayMs ?? config.httpRetryDelayMs ?? 400;
  let lastErr;

  for (let attempt = 0; attempt <= retries; attempt += 1) {
    try {
      const res = await client.request(options);
      return res.data;
    } catch (err) {
      lastErr = err;
      const status = err.response?.status;
      const retryable = !status || status >= 500 || status === 429;
      if (!retryable || attempt >= retries) break;
      await sleep(retryDelayMs * (attempt + 1));
    }
  }

  const status = lastErr?.response?.status;
  const url = options.url || options.baseURL || 'upstream';
  throw new UpstreamError(
    `Request failed for ${url}: ${lastErr?.message || 'unknown'}`,
    { status, cause: lastErr },
  );
}

/** Back-compat wrapper matching fetchJson signature. */
export async function fetchJson(url, options = {}) {
  const { timeoutMs, method = 'GET', body, headers, ...rest } = options;
  return requestJson({
    url,
    method,
    data: body,
    headers,
    timeout: timeoutMs ?? config.upstreamTimeoutMs,
    ...rest,
  });
}

export async function rpc(url, method, params = [], options = {}) {
  const data = await requestJson({
    url,
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
    data: { jsonrpc: '2.0', id: 1, method, params },
    timeout: options.timeoutMs ?? config.upstreamTimeoutMs,
  });
  if (data.error) {
    throw new UpstreamError(`RPC ${method} error: ${data.error.message || JSON.stringify(data.error)}`);
  }
  return data.result;
}
