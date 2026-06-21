/**
 * Sovereign Loop environment configuration utility.
 * Validates required keys on boot and reports fallback mode for dashboard logs.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = __dirname;

export const SOVEREIGN_ENV_KEYS = Object.freeze([
  {
    key: 'VAULT_SECRET_TOKEN',
    alt: 'VAULT_TOKEN',
    description: 'HashiCorp Vault access token for sovereign runtime secrets',
  },
  {
    key: 'SOVEREIGN_LOOP_KEY',
    description: 'Sovereign loop node signing key (inject via Vault, never commit)',
  },
  {
    key: 'NEXUS_RPC_URL',
    description: 'Nexus chain JSON-RPC endpoint for multi-chain treasury telemetry',
  },
  {
    key: 'IOTEX_API_KEY',
    description: 'IoTeX MachineFi API key for treasury balance ingestion',
  },
]);

function isProduction() {
  return process.env.NODE_ENV === 'production'
    || process.env.TARGET_ENV === 'mainnet'
    || process.env.SOVEREIGN_STRICT_MODE === '1';
}

function isStrictSimulation() {
  return process.env.SOVEREIGN_STRICT_SIMULATION === '1';
}

function resolveValue(spec) {
  if (process.env[spec.key]) return process.env[spec.key];
  if (spec.alt && process.env[spec.alt]) return process.env[spec.alt];
  return '';
}

/**
 * @returns {{ ok: boolean, fallbackMode: boolean, missing: string[], warnings: object[] }}
 */
export function validateSovereignEnv() {
  const missing = [];
  const warnings = [];

  for (const spec of SOVEREIGN_ENV_KEYS) {
    if (!resolveValue(spec)) {
      missing.push(spec.alt ? `${spec.key} or ${spec.alt}` : spec.key);
    }
  }

  const strict = isProduction() || isStrictSimulation();
  const fallbackMode = missing.length > 0;

  if (fallbackMode && strict) {
    warnings.push({
      ts: new Date().toISOString(),
      phase: 'config',
      message: 'Sovereign fallback mode engaged — missing required environment keys',
      type: 'warning',
      missing,
      mode: isProduction() ? 'production' : 'strict_simulation',
    });
  }

  return {
    ok: missing.length === 0,
    fallbackMode,
    missing,
    warnings,
    strict,
  };
}

/**
 * Append structured warnings to dashboard log sink (.run/env-warnings.jsonl).
 */
export async function logEnvWarningsToDashboard(warnings = []) {
  if (!warnings.length) return;
  const logPath = path.join(REPO_ROOT, '.run', 'env-warnings.jsonl');
  await fs.mkdir(path.dirname(logPath), { recursive: true });
  const lines = warnings.map((w) => `${JSON.stringify(w)}\n`).join('');
  await fs.appendFile(logPath, lines, 'utf8');
}

/**
 * Boot-time check — call from backend server or validation script.
 */
export async function bootEnvConfig() {
  const result = validateSovereignEnv();
  if (result.fallbackMode && result.strict) {
    for (const w of result.warnings) {
      console.warn(`[envConfig] ${w.message}: ${result.missing.join(', ')}`);
    }
    await logEnvWarningsToDashboard(result.warnings);
  }
  return result;
}
