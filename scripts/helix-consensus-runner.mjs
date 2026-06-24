#!/usr/bin/env node
/**
 * HELIX genesis consensus CLI — 100-round Shamir 9/14 smoke test.
 * Usage: node scripts/helix-consensus-runner.mjs [rounds]
 */
import { runConsensusSmokeTest } from '../backend/src/lib/consensusRunner.js';

const rounds = Math.min(Math.max(Number(process.argv[2]) || 100, 1), 100);
console.log(`Running HELIX consensus smoke test (${rounds} rounds)...`);
const result = runConsensusSmokeTest(rounds);
console.log(JSON.stringify(result, null, 2));
process.exit(result.ok ? 0 : 1);
