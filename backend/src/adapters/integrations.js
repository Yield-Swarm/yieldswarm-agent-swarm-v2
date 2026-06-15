/**
 * Council Wishlist integration adapter — proxies Odysseus brain when available.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import config from '../config.js';
import { fetchJson } from '../lib/http.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '..', '..', '..');
const BRAIN_BASE = config.odysseus.brainUrl;

function readLocalGovernanceReport() {
  const reportPath = path.join(repoRoot, '.run', 'governance-consensus-report.json');
  if (!fs.existsSync(reportPath)) return null;
  try {
    return JSON.parse(fs.readFileSync(reportPath, 'utf8'));
  } catch {
    return null;
  }
}

function fallbackIntegrations(reason) {
  return {
    source: 'fallback',
    live: false,
    reason,
    configured_count: 0,
    live_count: 0,
    configured_services: [],
    live_services: [],
    livepeer_skipped: true,
  };
}

export async function getIntegrationsHealth() {
  try {
    const data = await fetchJson(`${BRAIN_BASE}/api/integrations/health`, {
      timeoutMs: config.upstreamTimeoutMs,
    });
    return { ...data, source: 'odysseus-brain', live: true };
  } catch (err) {
    return fallbackIntegrations(err.message || 'integrations unreachable');
  }
}

export async function getGovernanceStatus() {
  try {
    const data = await fetchJson(`${BRAIN_BASE}/api/governance/consensus/status`, {
      timeoutMs: config.upstreamTimeoutMs,
    });
    return { ...data, source: 'odysseus-brain', live: true };
  } catch (err) {
    const local = readLocalGovernanceReport();
    return {
      source: 'fallback',
      live: Boolean(local),
      reason: err.message || 'governance status unreachable',
      consensus: local
        ? {
            threshold_met: local.consensus?.threshold_met,
            council_approvals: local.consensus?.council_approvals,
            governance_delta: local.governance_delta,
            autopilot_ready: local.autopilot_ready,
            model_count: local.model_count,
          }
        : {},
      gospel: { council_seats: 14, threshold: '9/14', model_count: 100 },
    };
  }
}

export async function runGovernanceConsensus(body = {}) {
  return fetchJson(`${BRAIN_BASE}/api/governance/consensus/run`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    timeoutMs: Math.max(config.upstreamTimeoutMs, 15000),
  });
}
