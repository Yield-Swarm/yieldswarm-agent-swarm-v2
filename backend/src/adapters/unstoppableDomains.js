/**
 * Unstoppable Domains API — domain resolution for command dashboard.
 * Uses UD_API_KEY from env / Vault (never hardcoded).
 */

import { fetchJson } from '../lib/http.js';

const UD_API = 'https://api.unstoppabledomains.com';

const DEFAULT_DOMAINS = [
  'yieldswarm.crypto',
  'yieldswarm.nft',
  'yieldswarm.wallet',
  'yieldswarm.x',
  'yieldswarm.dao',
  'helix.yieldswarm.crypto',
  'nexus.yieldswarm.crypto',
  'shadow.yieldswarm.crypto',
];

export function getConfiguredDomains() {
  const raw = process.env.UD_DOMAINS || process.env.YIELDSWARM_DOMAINS || '';
  const fromEnv = raw.split(',').map((d) => d.trim()).filter(Boolean);
  return fromEnv.length ? fromEnv : DEFAULT_DOMAINS;
}

export async function resolveDomain(domain) {
  const key = process.env.UD_API_KEY;
  if (!key || key.startsWith('your_')) {
    return { domain, configured: false, resolved: null, live: false };
  }
  try {
    const data = await fetchJson(`${UD_API}/resolve/domains/${encodeURIComponent(domain)}`, {
      headers: { Authorization: `Bearer ${key}` },
      timeoutMs: 8000,
    });
    return { domain, configured: true, resolved: data, live: true };
  } catch (err) {
    return { domain, configured: true, resolved: null, live: false, error: err.message };
  }
}

export async function getDomainsOverview() {
  const domains = getConfiguredDomains();
  const key = process.env.UD_API_KEY;
  const configured = Boolean(key && !key.startsWith('your_'));

  const results = await Promise.all(domains.map((d) => resolveDomain(d)));
  const liveCount = results.filter((r) => r.live).length;

  return {
    provider: 'unstoppable_domains',
    configured,
    domainCount: domains.length,
    liveCount,
    domains: results,
    docs: 'https://docs.unstoppabledomains.com/',
    timestamp: new Date().toISOString(),
  };
}
