/**
 * Cloudflare Worker — gateway.yieldswarm.crypto
 * Stable Akash API proxy with health check + simple failover.
 *
 * Deploy:
 *   wrangler deploy workers/gateway-yieldswarm-crypto.js
 *
 * Secrets (wrangler secret put):
 *   AKASH_ORIGIN — e.g. https://provider123.akash.pub:443
 *   AKASH_ORIGIN_FALLBACK — optional second lease URL
 *
 * Routes:
 *   gateway.yieldswarm.crypto/*
 *   api.yieldswarm.crypto/* (CNAME to gateway)
 */

const DEFAULT_TIMEOUT_MS = 25_000;

export default {
  async fetch(request, env) {
    const primary = env.AKASH_ORIGIN;
    const fallback = env.AKASH_ORIGIN_FALLBACK;
    if (!primary) {
      return new Response('AKASH_ORIGIN not configured', { status: 503 });
    }

    const url = new URL(request.url);
    const upstreamPath = url.pathname + url.search;

    let response = await proxy(request, primary, upstreamPath);
    if (shouldFailover(response) && fallback) {
      response = await proxy(request, fallback, upstreamPath);
    }

    return response;
  },
};

function shouldFailover(response) {
  return response.status >= 502 && response.status <= 504;
}

async function proxy(request, originBase, path) {
  const target = new URL(path, originBase.endsWith('/') ? originBase : originBase + '/');
  const headers = new Headers(request.headers);
  headers.set('Host', new URL(originBase).host);
  headers.delete('cf-connecting-ip');

  const init = {
    method: request.method,
    headers,
    redirect: 'manual',
    signal: AbortSignal.timeout(DEFAULT_TIMEOUT_MS),
  };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = request.body;
  }

  try {
    const resp = await fetch(target.toString(), init);
    const out = new Response(resp.body, resp);
    out.headers.set('x-yieldswarm-gateway', 'gateway.yieldswarm.crypto');
    out.headers.set('x-yieldswarm-upstream', originBase);
    return out;
  } catch (err) {
    return new Response(`upstream error: ${err.message}`, { status: 502 });
  }
}
