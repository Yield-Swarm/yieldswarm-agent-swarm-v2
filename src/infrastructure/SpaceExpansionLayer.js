/**
 * Helix Chain v5.0 — Simulated Space Expansion Matrix
 *
 * Tracks craft position in an expanding cosmic coordinate system with
 * Hubble-Lemaître metric expansion and Final Dimension boundary.
 */

'use strict';

/** Simulated Hubble constant (km/s/Mpc) */
const HUBBLE_KM_S_MPC = 70;

/** Megaparsec in kilometers */
const MPC_KM = 3.085677581e19;

/** Hubble parameter in s⁻¹ */
const H0 = (HUBBLE_KM_S_MPC * 1000) / MPC_KM;

/** Final Dimension boundary (simulated megaparsecs) */
const FINAL_DIMENSION_MPC = 13_800;

/** Light-year per megaparsec for display */
const LY_PER_MPC = 3.261563777e6;

function createInitialExpansionState() {
  return {
    cosmicTimeS: 0,
    scaleFactor: 1,
    positionMpc: 0.42,
    properVelocityKmS: 0,
    recessionVelocityKmS: 0,
    totalExpansionVelocityKmS: 0,
    spatialWarpingPct: 0,
    distanceToFinalDimensionMpc: FINAL_DIMENSION_MPC,
    finalDimensionReached: false,
    coordinateShift: { x: 0, y: 0, z: 0 },
  };
}

/**
 * Scale factor a(t) = exp(H₀ t) — simplified ΛCDM cosmic expansion.
 */
function scaleFactorAtTime(cosmicTimeS) {
  return Math.exp(H0 * cosmicTimeS);
}

/**
 * Recession velocity from metric expansion: v_rec = H₀ · d · a(t)
 */
function recessionVelocityKmS(distanceMpc, cosmicTimeS) {
  const dKm = distanceMpc * MPC_KM;
  const a = scaleFactorAtTime(cosmicTimeS);
  return (H0 * dKm * a) / 1000;
}

class SpaceExpansionLayer {
  constructor(options = {}) {
    this.finalDimensionMpc = options.finalDimensionMpc ?? FINAL_DIMENSION_MPC;
    this.state = { ...createInitialExpansionState(), ...options.initialState };
    this.state.distanceToFinalDimensionMpc = Math.max(
      0,
      this.finalDimensionMpc - this.state.positionMpc,
    );
  }

  getState() {
    return { ...this.state };
  }

  /**
   * Advance expansion layer by deltaTime given engine thrust telemetry.
   * @param {number} deltaTime — seconds
   * @param {{ thrustNewtons?: number, exhaustVelocityBeta?: number, massKg?: number }} engineTelemetry
   */
  updateExpansion(deltaTime, engineTelemetry = {}) {
    const dt = Math.max(0, Math.min(deltaTime, 2));
    const s = this.state;

    s.cosmicTimeS += dt;
    s.scaleFactor = scaleFactorAtTime(s.cosmicTimeS);

    const thrust = engineTelemetry.thrustNewtons ?? 0;
    const beta = engineTelemetry.exhaustVelocityBeta ?? 0;
    const massKg = engineTelemetry.massKg ?? 4200;

    // Proper acceleration from thrust → velocity (km/s)
    const accelMps2 = massKg > 0 ? thrust / massKg : 0;
    s.properVelocityKmS += (accelMps2 * dt) / 1000;

    // Cap proper velocity below 0.94c
    const maxProperKmS = beta * 299_792.458;
    if (maxProperKmS > 0) {
      s.properVelocityKmS = Math.min(s.properVelocityKmS, maxProperKmS);
    }

    s.recessionVelocityKmS = recessionVelocityKmS(s.positionMpc, s.cosmicTimeS);

    // Comoving distance drift from proper motion converted to Mpc
    const deltaMpc = (s.properVelocityKmS * 1000 * dt) / MPC_KM;
    s.positionMpc += deltaMpc * s.scaleFactor;

    s.totalExpansionVelocityKmS = s.properVelocityKmS + s.recessionVelocityKmS;
    s.distanceToFinalDimensionMpc = Math.max(0, this.finalDimensionMpc - s.positionMpc);
    s.finalDimensionReached = s.distanceToFinalDimensionMpc <= 0;

    // Spatial warping percentage — expansion stretch vs proper motion
    const warpDenom = Math.max(1, s.properVelocityKmS);
    s.spatialWarpingPct = Math.min(100, (s.recessionVelocityKmS / warpDenom) * 100);

    const phase = s.cosmicTimeS * 0.3;
    s.coordinateShift = {
      x: Math.sin(phase) * s.spatialWarpingPct * 0.01,
      y: Math.cos(phase * 0.7) * s.spatialWarpingPct * 0.01,
      z: Math.sin(phase * 1.3) * s.positionMpc * 0.0001,
    };

    return this.getState();
  }
}

function createSpaceExpansionLayer(options) {
  return new SpaceExpansionLayer(options);
}

module.exports = {
  SpaceExpansionLayer,
  createSpaceExpansionLayer,
  scaleFactorAtTime,
  recessionVelocityKmS,
  H0,
  FINAL_DIMENSION_MPC,
  LY_PER_MPC,
  createInitialExpansionState,
};
