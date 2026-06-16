/**
 * EntropyCore — rolling hardware telemetry → seed + ZK-ready public/private inputs.
 *
 * SHA-256 seed is the legacy on-chain identifier; Poseidon commitment is the
 * ZK public signal verified by circuits/entropy_proof.circom.
 */

const crypto = require("crypto");
const {
  WINDOW_SIZE,
  normalizeTelemetry,
  clampToBounds,
} = require("./entropy-bounds");
const { computeQualityFromWindow } = require("./entropy-circuit-inputs");

class EntropyCore {
  constructor(options = {}) {
    this.window = [];
    this.WINDOW_SIZE = options.windowSize ?? WINDOW_SIZE;
  }

  /**
   * @param {Record<string, unknown>} raw — { temp, power_draw, tokens_per_sec, error_rate, timestamp }
   * @returns {null | { seed: string, quality: number, commitment: string, zkInputs: object }}
   */
  ingest(raw) {
    const normalized = clampToBounds(normalizeTelemetry(raw));
    this.window.push(normalized);
    if (this.window.length > this.WINDOW_SIZE) {
      this.window.shift();
    }
    if (this.window.length === this.WINDOW_SIZE) {
      return this.generateSeedWithProof();
    }
    return null;
  }

  generateSeedWithProof() {
    const window = this.window.slice();
    const stringBlock = window.map((d) => `${d.t}${d.p}${d.s}${d.e}${d.ts}`).join("");
    const seed =
      "0x" + crypto.createHash("sha256").update(stringBlock).digest("hex").slice(0, 32);
    const quality = computeQualityFromWindow(window);

    const publicInputs = {
      seed,
      quality,
      // Filled by zk-entropy-prover / entropy-circuit-inputs (Poseidon chain)
      commitment: null,
    };

    const privateInputs = {
      telemetryWindow: window,
    };

    this.window = [];

    return {
      seed,
      quality,
      commitment: null,
      zkInputs: { public: publicInputs, private: privateInputs },
    };
  }
}

module.exports = { EntropyCore };
