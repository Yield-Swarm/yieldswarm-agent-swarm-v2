/**
 * ZK Entropy Prover — Groth16 proof generation (ZK¹ + D¹).
 *
 * Five-layer integration:
 *   D¹    — strict input sanitization, class boundaries
 *   E¹    — async proving, graceful degradation
 *   C¹+L¹ — rhythmic batching via external queue
 *   ZK¹   — Poseidon-bound entropy seeds
 *   PDs¹  — feeds MutationController co-evolution loop
 *
 * @module src/infrastructure/zk-entropy-prover
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { buildZkWitness, NODE_PROFILES } from './entropy-core.js';
import { resolveCircuit } from './zk-circuit-registry.js';

/** @typedef {'groth16'|'dev-hash'} ProveMode */

const ZK_ERROR_CODES = Object.freeze({
  INVALID_INPUT: 'ZK_INVALID_INPUT',
  RANGE_VIOLATION: 'ZK_RANGE_VIOLATION',
  PROVE_TIMEOUT: 'ZK_PROVE_TIMEOUT',
  ARTIFACT_MISSING: 'ZK_ARTIFACT_MISSING',
  VERIFY_FAILED: 'ZK_VERIFY_FAILED',
  SANITIZE_FAILED: 'ZK_SANITIZE_FAILED',
});

export { ZK_ERROR_CODES };

export class ZkEntropyProver {
  /**
   * @param {object} [opts]
   * @param {string} [opts.circuitVersion]
   * @param {number} [opts.maxRetries]
   * @param {number} [opts.proveTimeoutMs]
   */
  constructor(opts = {}) {
    this.circuitVersion = opts.circuitVersion ?? '1.0.0';
    this.maxRetries = opts.maxRetries ?? 3;
    this.proveTimeoutMs = opts.proveTimeoutMs ?? 30_000;
    this.metrics = {
      proofsGenerated: 0,
      proofsFailed: 0,
      totalProveMs: 0,
      lastProveMs: 0,
      mode: 'unknown',
    };
  }

  /**
   * D¹ — sanitize all inputs before proving (Tasks 6, 19).
   * @param {object} input
   */
  sanitizeInputs(input) {
    const telemetry = input.telemetry ?? {};
    const tokenId = BigInt(String(input.tokenId ?? '0').replace(/\D/g, '') || '0');
    const nonce = BigInt(Math.max(0, Math.floor(Number(input.nonce ?? 0))));

    const scaled = {
      gpuTempScaled: clampInt(telemetry.gpuTempC, 0, 100),
      vramScaled: clampInt(telemetry.vramUsedPct, 0, 100),
      powerScaled: clampInt(telemetry.powerWatts, 0, 600),
      inferenceTpsScaled: clampInt(telemetry.inferenceTps, 0, 200),
      packetLossScaled: clampInt(Math.round(Number(telemetry.packetLossPct ?? 0)), 0, 100),
      tokenId,
      nonce,
      nodeProfile: BigInt(NODE_PROFILES[telemetry.nodeProfile ?? 'rtx5090'] ?? 0),
    };

    for (const [k, v] of Object.entries(scaled)) {
      if (typeof v === 'bigint' && v < 0n) {
        throw proverError(ZK_ERROR_CODES.RANGE_VIOLATION, `negative ${k}`);
      }
    }

    return scaled;
  }

  /**
   * Generate Groth16 proof from telemetry (Tasks 35-37).
   * @param {object} input
   * @returns {Promise<object>}
   */
  async generateProof(input) {
    const start = Date.now();
    let lastError;

    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        const scaled = this.sanitizeInputs(input);
        const witness = buildZkWitness(scaled, input.telemetry);
        const circuit = resolveCircuit(this.circuitVersion);

        const artifactsExist = await fileExists(circuit.wasmPath) && await fileExists(circuit.zkeyPath);

        if (artifactsExist) {
          const result = await this._proveGroth16(circuit, witness, scaled);
          this._recordMetrics(start, 'groth16', true);
          return result;
        }

        // E¹ graceful degradation (Task 17)
        const devResult = this._proveDevHash(witness, scaled);
        this._recordMetrics(start, 'dev-hash', true);
        return devResult;
      } catch (err) {
        lastError = err;
        if (attempt < this.maxRetries) await sleep(250 * attempt);
      }
    }

    this._recordMetrics(start, 'failed', false);
    return {
      ok: false,
      error: lastError?.message ?? 'proof_failed',
      code: lastError?.code ?? ZK_ERROR_CODES.VERIFY_FAILED,
      metrics: { ...this.metrics },
    };
  }

  async _proveGroth16(circuit, witness, scaled) {
    const snarkjs = await import('snarkjs');
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.proveTimeoutMs);

    try {
      const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        witness.circuitInput,
        circuit.wasmPath,
        circuit.zkeyPath,
      );

      return {
        ok: true,
        mode: 'groth16',
        proof: formatProofForSolidity(proof),
        publicSignals: {
          entropySeed: publicSignals[0],
        },
        circuitVersion: this.circuitVersion,
        metrics: { proveMs: Date.now() },
        layers: layerTags('groth16'),
      };
    } finally {
      clearTimeout(timer);
    }
  }

  _proveDevHash(witness, scaled) {
    const payload = JSON.stringify(witness.public);
    const hash = createHash('sha256').update(payload).digest('hex');
    const entropySeed = BigInt(`0x${hash.slice(0, 16)}`).toString();

    return {
      ok: true,
      mode: 'dev-hash',
      proof: null,
      publicSignals: { entropySeed },
      circuitVersion: this.circuitVersion,
      warning: 'Circuit artifacts missing — dev-hash mode (not valid for mainnet)',
      metrics: { proveMs: 0 },
      layers: layerTags('dev-hash'),
    };
  }

  /**
   * Verify proof locally before on-chain submission (Task 38).
   */
  async verifyProofLocally(result) {
    if (!result.ok) return { valid: false, reason: 'generation_failed' };
    if (result.mode === 'dev-hash') return { valid: true, mode: 'dev-hash' };

    const circuit = resolveCircuit(result.circuitVersion ?? this.circuitVersion);
    const vkeyRaw = await fs.readFile(circuit.vkeyPath, 'utf8');
    const vkey = JSON.parse(vkeyRaw);
    const snarkjs = await import('snarkjs');

    const valid = await snarkjs.groth16.verify(
      vkey,
      [result.publicSignals.entropySeed],
      result.proof.raw,
    );
    return { valid, mode: 'groth16' };
  }

  /** E¹ observability (Task 16) */
  getMetrics() {
    return {
      ...this.metrics,
      successRate: this.metrics.proofsGenerated /
        Math.max(1, this.metrics.proofsGenerated + this.metrics.proofsFailed),
    };
  }

  _recordMetrics(start, mode, success) {
    const proveMs = Date.now() - start;
    this.metrics.lastProveMs = proveMs;
    this.metrics.totalProveMs += proveMs;
    this.metrics.mode = mode;
    if (success) this.metrics.proofsGenerated++;
    else this.metrics.proofsFailed++;
  }
}

function formatProofForSolidity(proof) {
  return {
    pi_a: [proof.pi_a[0], proof.pi_a[1]],
    pi_b: [[proof.pi_b[0][1], proof.pi_b[0][0]], [proof.pi_b[1][1], proof.pi_b[1][0]]],
    pi_c: [proof.pi_c[0], proof.pi_c[1]],
    raw: proof,
  };
}

function clampInt(v, min, max) {
  const n = Math.floor(Number(v));
  if (!Number.isFinite(n)) throw proverError(ZK_ERROR_CODES.INVALID_INPUT, 'non-numeric input');
  if (n < min || n > max) throw proverError(ZK_ERROR_CODES.RANGE_VIOLATION, `value ${n} outside [${min},${max}]`);
  return BigInt(n);
}

function proverError(code, message) {
  const err = new Error(message);
  err.code = code;
  return err;
}

async function fileExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function layerTags(mode) {
  return {
    greek: 'sanitized_inputs',
    eastern: mode === 'dev-hash' ? 'degraded_proving' : 'async_groth16',
    helix: 'rhythm_ready',
    zk: mode,
    paradigm: 'co_evolution_proof',
  };
}

export default ZkEntropyProver;
