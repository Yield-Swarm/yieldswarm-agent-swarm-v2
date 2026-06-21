/**
 * Helix Chain v5.0 (Delta Variant) — Antimatter Propulsion Physics Engine
 *
 * Simulates a relativistic proton-antiproton beam-core propulsion system with
 * Penning-trap antihydrogen containment and matter-antimatter annihilation.
 */

'use strict';

/** Speed of light (m/s) */
const C = 299_792_458;

/** Standard gravity (m/s²) */
const G0 = 9.80665;

/** Penning trap critical threshold — breach alarm below this (%) */
const PENNING_CRITICAL_PCT = 99.999;

/** Maximum theoretical specific impulse for annihilation drive (seconds) */
const ISP_TARGET = 10_000_000;

/** Initial antihydrogen stockpile (micrograms) */
const DEFAULT_FUEL_UG = 48.5;

/**
 * Relativistic exhaust velocity as a fraction of c.
 * Throttle maps to 0.3c–0.94c operational envelope.
 */
function exhaustBeta(throttle, annihilationEfficiency) {
  const t = Math.max(0, Math.min(1, throttle));
  const betaMin = 0.3;
  const betaMax = 0.94;
  const beta = betaMin + (betaMax - betaMin) * t * annihilationEfficiency;
  return Math.max(0, Math.min(0.999, beta));
}

/**
 * Relativistic specific impulse: Isp ≈ (γ * v_e) / g₀
 * Clamped toward the ~10M s antimatter annihilation target.
 */
function specificImpulse(beta) {
  const gamma = 1 / Math.sqrt(1 - beta * beta);
  const vExhaust = beta * C;
  const isp = (gamma * vExhaust) / G0;
  return Math.min(ISP_TARGET, isp);
}

function createInitialState() {
  return {
    fuelStockpileUg: DEFAULT_FUEL_UG,
    penningTrapIntegrityPct: 99.99995,
    annihilationRateNgPerS: 0,
    exhaustVelocityBeta: 0,
    specificImpulseS: 0,
    thrustNewtons: 0,
    thermalLoadMw: 0,
    gammaFluxSvPerS: 0,
    pionRadiationMevPerS: 0,
    containmentBreach: false,
    annihilationEfficiency: 0.997,
    chamberTemperatureK: 2.7,
    clockCycles: 0,
  };
}

class AntimatterEngineV5 {
  constructor(options = {}) {
    this.state = { ...createInitialState(), ...options.initialState };
    this._rngSeed = options.seed ?? Date.now();
  }

  /** Deterministic micro-jitter for trap field simulation */
  _jitter(magnitude = 1) {
    const x = Math.sin(this._rngSeed++ * 12.9898) * 43758.5453;
    return (x - Math.floor(x) - 0.5) * magnitude;
  }

  getState() {
    return { ...this.state };
  }

  /**
   * Advance engine physics by deltaTime seconds at given throttle (0–1).
   * @returns {{ thrustNewtons: number, wasteHeatMw: number, fuelConsumedNg: number, alarm: boolean }}
   */
  updateEngineState(deltaTime, throttle = 0) {
    const dt = Math.max(0, Math.min(deltaTime, 2));
    const t = Math.max(0, Math.min(1, throttle));
    const s = this.state;

    // Penning trap field degrades under thrust and thermal load
    const fieldStress = t * 0.00008 + s.thermalLoadMw * 0.00002;
    const fieldRecovery = t < 0.05 ? 0.00003 : 0;
    s.penningTrapIntegrityPct += fieldRecovery - fieldStress + this._jitter(0.00004);
    s.penningTrapIntegrityPct = Math.max(0, Math.min(100, s.penningTrapIntegrityPct));

    s.containmentBreach = s.penningTrapIntegrityPct < PENNING_CRITICAL_PCT;

    // Annihilation rate: nanograms per second at full throttle ~850 ng/s
    const maxRateNgPerS = 850;
    s.annihilationRateNgPerS = t * maxRateNgPerS * s.annihilationEfficiency;

    if (s.containmentBreach) {
      s.annihilationRateNgPerS *= 0.02;
    }

    const fuelConsumedNg = s.annihilationRateNgPerS * dt;
    const fuelConsumedUg = fuelConsumedNg / 1000;
    s.fuelStockpileUg = Math.max(0, s.fuelStockpileUg - fuelConsumedUg);

    const beta = exhaustBeta(t, s.annihilationEfficiency);
    s.exhaustVelocityBeta = beta;
    s.specificImpulseS = specificImpulse(beta);

    // ṁ in kg/s; thrust F ≈ ṁ c β γ (relativistic beam-core approximation)
    const mdotKgPerS = (s.annihilationRateNgPerS * 1e-12) * 2;
    const gamma = 1 / Math.sqrt(1 - beta * beta);
    s.thrustNewtons = mdotKgPerS * C * beta * gamma;

  // Annihilation releases ~1.8×10¹⁴ J/kg; capture fraction becomes waste heat
    const powerWatts = mdotKgPerS * C * C;
    const wasteFraction = 0.18;
    s.thermalLoadMw = (powerWatts * wasteFraction) / 1e6;
    s.chamberTemperatureK = 2.7 + s.thermalLoadMw * 0.42;

    s.gammaFluxSvPerS = s.annihilationRateNgPerS * 0.084;
    s.pionRadiationMevPerS = s.annihilationRateNgPerS * 312;

    s.clockCycles += 1;

    return {
      thrustNewtons: s.thrustNewtons,
      wasteHeatMw: s.thermalLoadMw,
      fuelConsumedNg,
      alarm: s.containmentBreach,
      exhaustVelocityMs: beta * C,
      specificImpulseS: s.specificImpulseS,
    };
  }
}

/** Singleton-friendly factory */
function createAntimatterEngineV5(options) {
  return new AntimatterEngineV5(options);
}

/**
 * Standalone tick function for stateless consumers.
 * Mutates and returns engineState object.
 */
function updateEngineState(engineState, deltaTime, throttle) {
  const engine = new AntimatterEngineV5({ initialState: engineState });
  engine.updateEngineState(deltaTime, throttle);
  return engine.getState();
}

module.exports = {
  AntimatterEngineV5,
  createAntimatterEngineV5,
  updateEngineState,
  C,
  G0,
  ISP_TARGET,
  PENNING_CRITICAL_PCT,
};
