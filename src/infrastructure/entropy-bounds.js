/**
 * Normalization + bounds for hardware telemetry used in entropy + ZK circuits.
 * Values are integers to match circom field arithmetic.
 */

/** @typedef {{ t: number, p: number, s: number, e: number, ts: number }} NormalizedTelemetry */

const BOUNDS = {
  t: { min: 3_000, max: 9_500 },   // temp °C × 100
  p: { min: 50, max: 800 },        // watts
  s: { min: 0, max: 100_000 },     // tokens/sec × 100
  e: { min: 0, max: 1_000 },       // error rate × 10_000
};

const WINDOW_SIZE = 128;

function normalizeTelemetry(raw) {
  return {
    t: Math.round(Number(raw.temp ?? raw.t ?? 0) * 100),
    p: Math.round(Number(raw.power_draw ?? raw.p ?? 0)),
    s: Math.round(Number(raw.tokens_per_sec ?? raw.s ?? 0) * 100),
    e: Math.round(Number(raw.error_rate ?? raw.e ?? 0) * 10_000),
    ts: Math.round(Number(raw.timestamp ?? raw.ts ?? Date.now())),
  };
}

function clampToBounds(point) {
  const out = { ...point };
  for (const key of ["t", "p", "s", "e"]) {
    const { min, max } = BOUNDS[key];
    out[key] = Math.max(min, Math.min(max, out[key]));
  }
  return out;
}

function isWithinBounds(point) {
  return ["t", "p", "s", "e"].every((key) => {
    const v = point[key];
    return v >= BOUNDS[key].min && v <= BOUNDS[key].max;
  });
}

/**
 * Deterministic quality score 85–100 from in-bounds telemetry stability.
 * @param {NormalizedTelemetry[]} window
 */
function computeQuality(window) {
  if (!window.length) return 85;
  const inBounds = window.filter(isWithinBounds).length;
  const ratio = inBounds / window.length;
  return Math.min(100, 85 + Math.floor(ratio * 15));
}

module.exports = {
  BOUNDS,
  WINDOW_SIZE,
  normalizeTelemetry,
  clampToBounds,
  isWithinBounds,
  computeQuality,
};
