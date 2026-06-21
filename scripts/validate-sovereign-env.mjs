#!/usr/bin/env node
/**
 * Lightweight validation script for Sovereign Loop environment variables.
 * Usage: node scripts/validate-sovereign-env.mjs [--strict]
 */

import { bootEnvConfig, validateSovereignEnv } from '../envConfig.js';

const strict = process.argv.includes('--strict');

if (strict) {
  process.env.SOVEREIGN_STRICT_SIMULATION = '1';
}

const result = validateSovereignEnv();

console.log(JSON.stringify({
  ok: result.ok,
  fallbackMode: result.fallbackMode,
  missing: result.missing,
  strict: result.strict,
}, null, 2));

if (result.warnings.length) {
  await bootEnvConfig();
}

process.exit(result.ok ? 0 : 1);
