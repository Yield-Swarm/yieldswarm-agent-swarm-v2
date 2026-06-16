#!/usr/bin/env bash
# Local proof smoke test (ZK¹ Task 38)
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/.."

node --input-type=module <<'NODE'
import { ZkEntropyProver } from '../src/infrastructure/zk-entropy-prover.js';

const prover = new ZkEntropyProver({ circuitVersion: '1.0.0' });
const telemetry = {
  gpuTempC: 72,
  vramUsedPct: 65,
  powerWatts: 380,
  inferenceTps: 95,
  packetLossPct: 0.5,
  nodeProfile: 'rtx5090',
};

const result = await prover.generateProof({ telemetry, tokenId: '42', nonce: 1 });
console.log(JSON.stringify({
  ok: result.ok,
  mode: result.mode,
  entropySeed: result.publicSignals?.entropySeed,
  proveMs: result.metrics?.proveMs,
}, null, 2));

if (!result.ok) process.exit(1);
NODE
