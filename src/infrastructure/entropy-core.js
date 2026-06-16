/**
 * Eastern layer ($E^1$) — HardenedAuditEngine (entropy-core).
 *
 * Ingests hardware telemetry into a rolling 64-block window and compiles
 * append-only state chains with deterministic blockVerificationHash.
 * Integrates ZK¹ entropy proofs for verifiable living memory (A¹ + U¹).
 */

import crypto from "node:crypto";
import { entropyQualityScore, generateGroth16Proof } from "./zk-entropy-prover.js";

export const WINDOW_SIZE = 64;

/**
 * @typedef {object} TelemetrySample
 * @property {number} vramUsedGb
 * @property {number} tempC
 * @property {number} [powerW]
 * @property {number} [utilizationPct]
 * @property {string} [gpuId]
 * @property {number} [timestamp]
 */

/**
 * @typedef {object} AuditBlock
 * @property {number} index
 * @property {string} prevHash
 * @property {string} sampleHash
 * @property {string} blockVerificationHash
 * @property {TelemetrySample} sample
 * @property {string} sealedAt
 */

export class HardenedAuditEngine {
  constructor() {
    /** @type {AuditBlock[]} */
    this.chain = [];
    this.genesisHash = crypto.createHash("sha256").update("helix-entropy-genesis").digest("hex");
  }

  /**
   * Hash a telemetry sample deterministically (raw metrics never leave this digest in proofs).
   * @param {TelemetrySample} sample
   * @returns {string}
   */
  hashSample(sample) {
    const normalized = {
      vramUsedGb: Number(sample.vramUsedGb.toFixed(4)),
      tempC: Number(sample.tempC.toFixed(2)),
      powerW: sample.powerW !== undefined ? Number(sample.powerW.toFixed(2)) : 0,
      utilizationPct:
        sample.utilizationPct !== undefined ? Number(sample.utilizationPct.toFixed(2)) : 0,
      gpuId: sample.gpuId || "gpu0",
      timestamp: sample.timestamp || Date.now(),
    };
    return crypto.createHash("sha256").update(JSON.stringify(normalized)).digest("hex");
  }

  /**
   * Compute block verification hash linking prev + sample.
   * @param {string} prevHash
   * @param {string} sampleHash
   * @param {number} index
   * @returns {string}
   */
  computeBlockVerificationHash(prevHash, sampleHash, index) {
    return crypto
      .createHash("sha256")
      .update(`${prevHash}:${sampleHash}:${index}`)
      .digest("hex");
  }

  /**
   * Validate sample is within acceptable hardware envelope.
   * @param {TelemetrySample} sample
   */
  validateSample(sample) {
    if (typeof sample.vramUsedGb !== "number" || sample.vramUsedGb < 0 || sample.vramUsedGb > 64) {
      throw new RangeError("vramUsedGb out of range [0, 64]");
    }
    if (typeof sample.tempC !== "number" || sample.tempC < 0 || sample.tempC > 120) {
      throw new RangeError("tempC out of range [0, 120]");
    }
    return true;
  }

  /**
   * Append telemetry to the rolling window chain.
   * @param {TelemetrySample} sample
   * @returns {AuditBlock}
   */
  ingest(sample) {
    this.validateSample(sample);

    const prevHash =
      this.chain.length === 0
        ? this.genesisHash
        : this.chain[this.chain.length - 1].blockVerificationHash;

    const index = this.chain.length;
    const sampleHash = this.hashSample(sample);
    const blockVerificationHash = this.computeBlockVerificationHash(prevHash, sampleHash, index);

    /** @type {AuditBlock} */
    const block = {
      index,
      prevHash,
      sampleHash,
      blockVerificationHash,
      sample: {
        ...sample,
        timestamp: sample.timestamp || Date.now(),
      },
      sealedAt: new Date().toISOString(),
    };

    this.chain.push(block);

    if (this.chain.length > WINDOW_SIZE) {
      this.chain = this.chain.slice(-WINDOW_SIZE);
      this._rechainWindow();
    }

    return block;
  }

  /** Recompute hashes after window trim — reset indices to 0..n-1. */
  _rechainWindow() {
    let prev = this.genesisHash;
    for (let i = 0; i < this.chain.length; i++) {
      const block = this.chain[i];
      block.index = i;
      block.prevHash = prev;
      block.sampleHash = this.hashSample(block.sample);
      block.blockVerificationHash = this.computeBlockVerificationHash(prev, block.sampleHash, i);
      prev = block.blockVerificationHash;
    }
  }

  /**
   * Verify chain integrity within the current window.
   * @returns {{ valid: boolean, errors: string[] }}
   */
  verifyChain() {
    const errors = [];
    let prev = this.genesisHash;

    for (let i = 0; i < this.chain.length; i++) {
      const block = this.chain[i];
      if (block.prevHash !== prev) {
        errors.push(`block ${i}: prevHash mismatch`);
      }
      const expectedSample = this.hashSample(block.sample);
      if (block.sampleHash !== expectedSample) {
        errors.push(`block ${i}: sampleHash mismatch`);
      }
      const expectedBlock = this.computeBlockVerificationHash(block.prevHash, block.sampleHash, i);
      if (block.blockVerificationHash !== expectedBlock) {
        errors.push(`block ${i}: blockVerificationHash mismatch`);
      }
      prev = block.blockVerificationHash;
    }

    return { valid: errors.length === 0, errors };
  }

  /**
   * Export proof seed for ZK circuit (commitment without revealing raw metrics).
   * @returns {{ windowRoot: string, blockCount: number, latestBlockHash: string | null }}
   */
  exportProofSeed() {
    const latest = this.chain[this.chain.length - 1];
    const windowRoot = crypto
      .createHash("sha256")
      .update(this.chain.map((b) => b.blockVerificationHash).join(":"))
      .digest("hex");

    return {
      windowRoot,
      blockCount: this.chain.length,
      latestBlockHash: latest?.blockVerificationHash ?? null,
    };
  }

  getWindow() {
    return [...this.chain];
  }

  /**
   * Compute rolling entropy quality for O¹ oscillator + sovereign routing.
   * @returns {number} 0–1 quality score
   */
  entropyQuality() {
    if (this.chain.length === 0) return 0;
    const recent = this.chain.slice(-8);
    const scores = recent.map((b) => entropyQualityScore(b.sample));
    return scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  /**
   * Generate ZK entropy seed + proof from latest window block (A¹ Ancestral memory).
   * Raw metrics stay private; only commitment + public signals are exported.
   * @param {object} [opts]
   * @param {number} [opts.blockIndex] defaults to latest block
   * @returns {Promise<object>}
   */
  async generateSeedWithProof(opts = {}) {
    const idx = opts.blockIndex ?? this.chain.length - 1;
    if (idx < 0 || idx >= this.chain.length) {
      throw new RangeError("no blocks in window — ingest telemetry first");
    }

    const block = this.chain[idx];
    const chainVerify = this.verifyChain();
    if (!chainVerify.valid) {
      throw new Error(`chain invalid: ${chainVerify.errors.join("; ")}`);
    }

    const proofBundle = await generateGroth16Proof({
      ...block.sample,
      nonce: block.index,
    });

    const seed = this.exportProofSeed();

    return {
      pillar: "A1-Ancestral",
      testimony: "U1-Living-Logos",
      windowRoot: seed.windowRoot,
      blockVerificationHash: block.blockVerificationHash,
      blockIndex: block.index,
      entropyQuality: this.entropyQuality(),
      commitment: proofBundle.commitment,
      publicSignals: proofBundle.publicSignals,
      proof: proofBundle.proof,
      devMode: proofBundle.devMode ?? false,
      generatedAt: new Date().toISOString(),
    };
  }
}

export const hardenedAuditEngine = new HardenedAuditEngine();

export default hardenedAuditEngine;
