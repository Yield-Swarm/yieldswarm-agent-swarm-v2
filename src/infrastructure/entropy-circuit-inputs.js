/**
 * Poseidon commitment + witness shaping for circuits/entropy_proof.circom.
 * Must stay in sync with the circom template (Poseidon(5) per sample, Poseidon(2) fold).
 */

const BOUNDS = {
  t: { min: 3_000, max: 9_500 },
  p: { min: 50, max: 800 },
  s: { min: 0, max: 100_000 },
  e: { min: 0, max: 1_000 },
};

/** @type {import('circomlibjs').Poseidon | null} */
let poseidon = null;

async function initPoseidon() {
  if (poseidon) return poseidon;
  const { buildPoseidon } = await import("circomlibjs");
  poseidon = await buildPoseidon();
  return poseidon;
}

/**
 * @param {{ t: number, p: number, s: number, e: number, ts: number }} sample
 */
function sampleToField(sample) {
  return [sample.t, sample.p, sample.s, sample.e, sample.ts].map((n) => BigInt(n));
}

/**
 * @param {{ t: number, p: number, s: number, e: number, ts: number }[]} window
 */
async function computeCommitment(window) {
  const p = await initPoseidon();
  let rolling = 0n;
  for (const sample of window) {
    const fields = sampleToField(sample);
    const sampleHash = p(fields);
    rolling = p([rolling, p.F.toObject(sampleHash)]);
  }
  const commitment = p.F.toObject(rolling);
  return "0x" + commitment.toString(16).padStart(64, "0");
}

function commitmentToBigInt(commitmentHex) {
  return BigInt(commitmentHex);
}

/**
 * Flatten telemetry window for circom/snarkjs input.
 * @param {{ t: number, p: number, s: number, e: number, ts: number }[]} window
 */
function flattenTelemetry(window) {
  return window.map((s) => [s.t, s.p, s.s, s.e, s.ts]);
}

/**
 * Build snarkjs input object for entropy_proof.circom
 * @param {{ telemetryWindow: object[] }} privateInputs
 * @param {{ quality: number, commitment: string }} publicInputs
 */
function buildCircuitInput(privateInputs, publicInputs) {
  const commitment =
    typeof publicInputs.commitment === "string"
      ? commitmentToBigInt(publicInputs.commitment)
      : BigInt(publicInputs.commitment);

  return {
    telemetry: flattenTelemetry(privateInputs.telemetryWindow),
    quality: publicInputs.quality,
    outCommitment: commitment.toString(),
    outQuality: publicInputs.quality,
  };
}

function isWithinBounds(point) {
  return ["t", "p", "s", "e"].every((key) => {
    const v = point[key];
    return v >= BOUNDS[key].min && v <= BOUNDS[key].max;
  });
}

/**
 * @param {{ t: number, p: number, s: number, e: number, ts: number }[]} window
 */
function computeQualityFromWindow(window) {
  if (!window.length) return 85;
  const inBounds = window.filter(isWithinBounds).length;
  return Math.min(100, 85 + Math.floor((inBounds / window.length) * 15));
}

module.exports = {
  BOUNDS,
  initPoseidon,
  computeCommitment,
  commitmentToBigInt,
  flattenTelemetry,
  buildCircuitInput,
  computeQualityFromWindow,
};
