/**
 * ZK¹ Verifiable layer — entropy seed prover with sanitization and Groth16 integration.
 *
 * Proves hardware telemetry is within policy bounds without revealing raw vram/temp.
 * Uses circomlibjs Poseidon (matches circuits/entropy_proof.circom) and snarkjs when
 * build artifacts exist under circuits/build/.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { buildPoseidon } from "circomlibjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const CIRCUIT_BUILD = path.join(REPO_ROOT, "circuits", "build");
const WASM_PATH = path.join(CIRCUIT_BUILD, "entropy_proof_js", "entropy_proof.wasm");
const ZKEY_PATH = path.join(CIRCUIT_BUILD, "entropy_proof_final.zkey");

/** Policy ceilings (scaled ×1000) — RTX 5090 guardrails align with entrypoint.monitor.sh */
export const DEFAULT_POLICY = {
  vramMaxGb: 29.5,
  tempMaxC: 83,
  scale: 1000,
};

let poseidonInstance = null;

/**
 * @param {unknown} raw
 * @returns {number}
 */
function toScaled(raw, scale = DEFAULT_POLICY.scale) {
  return Math.round(Number(raw) * scale);
}

/**
 * Sanitize telemetry before witness generation (D¹ Greek isolation).
 * @param {object} sample
 * @returns {{ vramScaled: number, tempScaled: number, vramMaxScaled: number, tempMaxScaled: number, nonce: number }}
 */
export function sanitizeTelemetry(sample, policy = DEFAULT_POLICY) {
  if (!sample || typeof sample !== "object") {
    throw new TypeError("sample must be an object");
  }

  const vramGb = Number(sample.vramUsedGb ?? sample.vramGb ?? 0);
  const tempC = Number(sample.tempC ?? sample.temperatureC ?? 0);

  if (!Number.isFinite(vramGb) || vramGb < 0 || vramGb > 64) {
    throw new RangeError("vramUsedGb out of range [0, 64]");
  }
  if (!Number.isFinite(tempC) || tempC < 0 || tempC > 120) {
    throw new RangeError("tempC out of range [0, 120]");
  }

  const vramMaxScaled = toScaled(policy.vramMaxGb, policy.scale);
  const tempMaxScaled = toScaled(policy.tempMaxC, policy.scale);
  const vramScaled = toScaled(vramGb, policy.scale);
  const tempScaled = toScaled(tempC, policy.scale);

  if (vramScaled > vramMaxScaled) {
    throw new RangeError(`vram ${vramGb}GB exceeds policy max ${policy.vramMaxGb}GB`);
  }
  if (tempScaled > tempMaxScaled) {
    throw new RangeError(`temp ${tempC}C exceeds policy max ${policy.tempMaxC}C`);
  }

  const nonce = Number(sample.nonce ?? sample.timestamp ?? Date.now()) % 2 ** 31;

  return { vramScaled, tempScaled, vramMaxScaled, tempMaxScaled, nonce };
}

/**
 * Lazy-init Poseidon hasher (matches circom Poseidon(3)).
 */
export async function getPoseidon() {
  if (!poseidonInstance) {
    poseidonInstance = await buildPoseidon();
  }
  return poseidonInstance;
}

/**
 * Compute public commitment = Poseidon(vramScaled, tempScaled, nonce).
 * @param {object} witness
 */
export async function computeCommitment(witness) {
  const poseidon = await getPoseidon();
  const hash = poseidon([witness.vramScaled, witness.tempScaled, witness.nonce]);
  const F = poseidon.F;
  return F.toString(hash);
}

/**
 * Build circuit input object for witness generation.
 */
export async function buildCircuitInput(sample, policy = DEFAULT_POLICY) {
  const witness = sanitizeTelemetry(sample, policy);
  const commitment = await computeCommitment(witness);
  return {
    commitment,
    vramMaxScaled: witness.vramMaxScaled,
    tempMaxScaled: witness.tempMaxScaled,
    vramScaled: witness.vramScaled,
    tempScaled: witness.tempScaled,
    nonce: witness.nonce,
  };
}

/**
 * Check whether compiled circuit artifacts are available for full Groth16 proving.
 */
export function hasGroth16Artifacts() {
  return fs.existsSync(WASM_PATH) && fs.existsSync(ZKEY_PATH);
}

/**
 * Generate a development-mode proof (public signals + commitment binding).
 * Used when circom build artifacts are not present (CI / local without circom).
 */
export async function generateDevProof(sample, policy = DEFAULT_POLICY) {
  const input = await buildCircuitInput(sample, policy);
  return {
    devMode: true,
    publicSignals: [input.commitment, String(input.vramMaxScaled), String(input.tempMaxScaled)],
    proof: {
      a: ["1", "2"],
      b: [["3", "4"], ["5", "6"]],
      c: ["7", "8"],
    },
    witness: {
      vramScaled: input.vramScaled,
      tempScaled: input.tempScaled,
      nonce: input.nonce,
    },
    commitment: input.commitment,
    generatedAt: new Date().toISOString(),
  };
}

/**
 * Generate full Groth16 proof via snarkjs (requires circuits/build artifacts).
 */
export async function generateGroth16Proof(sample, policy = DEFAULT_POLICY) {
  if (!hasGroth16Artifacts()) {
    return generateDevProof(sample, policy);
  }

  const snarkjs = await import("snarkjs");
  const input = await buildCircuitInput(sample, policy);

  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    {
      commitment: input.commitment,
      vramMaxScaled: input.vramMaxScaled,
      tempMaxScaled: input.tempMaxScaled,
      vramScaled: input.vramScaled,
      tempScaled: input.tempScaled,
      nonce: input.nonce,
    },
    WASM_PATH,
    ZKEY_PATH,
  );

  return {
    devMode: false,
    proof,
    publicSignals,
    commitment: input.commitment,
    generatedAt: new Date().toISOString(),
  };
}

/**
 * Verify proof locally (snarkjs or dev-mode structural check).
 */
export async function verifyProofLocally(proofBundle, policy = DEFAULT_POLICY) {
  if (proofBundle.devMode) {
    const [commitment, vramMax, tempMax] = proofBundle.publicSignals;
    const witness = proofBundle.witness;
    if (!witness) return { valid: false, reason: "missing witness in dev proof" };
    const expected = await computeCommitment(witness);
    if (String(commitment) !== String(expected)) {
      return { valid: false, reason: "commitment mismatch" };
    }
    if (Number(vramMax) !== toScaled(policy.vramMaxGb, policy.scale)) {
      return { valid: false, reason: "vramMaxScaled mismatch" };
    }
    if (Number(tempMax) !== toScaled(policy.tempMaxC, policy.scale)) {
      return { valid: false, reason: "tempMaxScaled mismatch" };
    }
    return { valid: true, mode: "dev" };
  }

  if (!hasGroth16Artifacts()) {
    return { valid: false, reason: "verification key not available" };
  }

  const snarkjs = await import("snarkjs");
  const vkeyPath = path.join(CIRCUIT_BUILD, "verification_key.json");
  if (!fs.existsSync(vkeyPath)) {
    return { valid: false, reason: "verification_key.json missing" };
  }
  const vkey = JSON.parse(fs.readFileSync(vkeyPath, "utf8"));
  const ok = await snarkjs.groth16.verify(vkey, proofBundle.publicSignals, proofBundle.proof);
  return { valid: ok, mode: "groth16" };
}

/**
 * Entropy quality score 0–1 for routing (U¹ Living Logos feedback).
 * Higher = more stable telemetry (lower temp/vram utilization vs ceiling).
 */
export function entropyQualityScore(sample, policy = DEFAULT_POLICY) {
  const vramGb = Number(sample.vramUsedGb ?? 0);
  const tempC = Number(sample.tempC ?? 0);
  const vramHeadroom = Math.max(0, policy.vramMaxGb - vramGb) / policy.vramMaxGb;
  const tempHeadroom = Math.max(0, policy.tempMaxC - tempC) / policy.tempMaxC;
  return Math.min(1, (vramHeadroom * 0.55 + tempHeadroom * 0.45));
}

export class ZkEntropyProver {
  constructor(policy = DEFAULT_POLICY) {
    this.policy = policy;
    /** @type {Map<string, object>} */
    this.proofCache = new Map();
  }

  async prove(sample) {
    const proof = await generateGroth16Proof(sample, this.policy);
    this.proofCache.set(proof.commitment, proof);
    return proof;
  }

  async verify(proofBundle) {
    return verifyProofLocally(proofBundle, this.policy);
  }
}

export const zkEntropyProver = new ZkEntropyProver();

export default zkEntropyProver;
