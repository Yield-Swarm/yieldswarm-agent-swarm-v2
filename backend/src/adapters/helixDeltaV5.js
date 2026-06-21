/**
 * Helix Chain v5.0 Delta Variant — unified telemetry adapter.
 */

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

const infraPath = path.resolve(__dirname, '..', '..', '..', 'src', 'infrastructure');
const { createAntimatterEngineV5, PENNING_CRITICAL_PCT, ISP_TARGET, C } = require(
  path.join(infraPath, 'AntimatterEngineV5.js'),
);
const { createSpaceExpansionLayer, FINAL_DIMENSION_MPC, LY_PER_MPC } = require(
  path.join(infraPath, 'SpaceExpansionLayer.js'),
);

let engine = createAntimatterEngineV5();
let expansion = createSpaceExpansionLayer();
let throttle = 0.65;
let lastTickAt = Date.now();

function tickSimulation(deltaTime) {
  const engineResult = engine.updateEngineState(deltaTime, throttle);
  const engineState = engine.getState();
  expansion.updateExpansion(deltaTime, {
    thrustNewtons: engineResult.thrustNewtons,
    exhaustVelocityBeta: engineState.exhaustVelocityBeta,
  });
  return { engineState, expansionState: expansion.getState(), engineResult };
}

function ensureTicked() {
  const now = Date.now();
  let dt = Math.min(2, (now - lastTickAt) / 1000);
  lastTickAt = now;
  if (dt < 0.05) {
    dt = 0.1;
  }
  tickSimulation(dt);
}

export function setHelixDeltaThrottle(value) {
  throttle = Math.max(0, Math.min(1, Number(value) || 0));
}

export function getHelixDeltaTelemetry() {
  ensureTicked();
  const engineState = engine.getState();
  const expansionState = expansion.getState();

  return {
    variant: 'helix-v5.0-delta',
    generatedAt: new Date().toISOString(),
    throttle,
    engine: {
      fuelStockpileUg: engineState.fuelStockpileUg,
      penningTrapIntegrityPct: engineState.penningTrapIntegrityPct,
      penningTrapCriticalPct: PENNING_CRITICAL_PCT,
      containmentBreach: engineState.containmentBreach,
      annihilationRateNgPerS: engineState.annihilationRateNgPerS,
      exhaustVelocityBeta: engineState.exhaustVelocityBeta,
      exhaustVelocityC: engineState.exhaustVelocityBeta,
      specificImpulseS: engineState.specificImpulseS,
      ispTargetS: ISP_TARGET,
      thrustNewtons: engineState.thrustNewtons,
      thermalLoadMw: engineState.thermalLoadMw,
      gammaFluxSvPerS: engineState.gammaFluxSvPerS,
      pionRadiationMevPerS: engineState.pionRadiationMevPerS,
      chamberTemperatureK: engineState.chamberTemperatureK,
      clockCycles: engineState.clockCycles,
    },
    expansion: {
      scaleFactor: expansionState.scaleFactor,
      positionMpc: expansionState.positionMpc,
      positionLy: expansionState.positionMpc * LY_PER_MPC,
      properVelocityKmS: expansionState.properVelocityKmS,
      recessionVelocityKmS: expansionState.recessionVelocityKmS,
      totalExpansionVelocityKmS: expansionState.totalExpansionVelocityKmS,
      spatialWarpingPct: expansionState.spatialWarpingPct,
      distanceToFinalDimensionMpc: expansionState.distanceToFinalDimensionMpc,
      distanceToFinalDimensionLy: expansionState.distanceToFinalDimensionMpc * LY_PER_MPC,
      finalDimensionBoundaryMpc: FINAL_DIMENSION_MPC,
      finalDimensionReached: expansionState.finalDimensionReached,
      coordinateShift: expansionState.coordinateShift,
      cosmicTimeS: expansionState.cosmicTimeS,
    },
    constants: { c: C },
    solenoid: { ring: 2, phase: 'Solenoid2ApiGrid', quadrant: 'Helix/Reverberator' },
  };
}

export function resetHelixDeltaSimulation() {
  engine = createAntimatterEngineV5();
  expansion = createSpaceExpansionLayer();
  throttle = 0.65;
  lastTickAt = Date.now();
}

export default { getHelixDeltaTelemetry, setHelixDeltaThrottle, resetHelixDeltaSimulation };
