import { create } from "zustand";
// @ts-expect-error CJS infrastructure module
import { createAntimatterEngineV5 } from "@infra/AntimatterEngineV5.js";
// @ts-expect-error CJS infrastructure module
import { createSpaceExpansionLayer } from "@infra/SpaceExpansionLayer.js";

export type EngineTelemetry = {
  fuelStockpileUg: number;
  penningTrapIntegrityPct: number;
  containmentBreach: boolean;
  annihilationRateNgPerS: number;
  exhaustVelocityBeta: number;
  specificImpulseS: number;
  thrustNewtons: number;
  thermalLoadMw: number;
  gammaFluxSvPerS: number;
  pionRadiationMevPerS: number;
};

export type ExpansionTelemetry = {
  scaleFactor: number;
  positionMpc: number;
  properVelocityKmS: number;
  recessionVelocityKmS: number;
  totalExpansionVelocityKmS: number;
  spatialWarpingPct: number;
  distanceToFinalDimensionMpc: number;
  finalDimensionReached: boolean;
  coordinateShift: { x: number; y: number; z: number };
};

type HelixDeltaState = {
  throttle: number;
  focused: boolean;
  engine: EngineTelemetry;
  expansion: ExpansionTelemetry;
  lastTickAt: number;
  _engine: ReturnType<typeof createAntimatterEngineV5>;
  _expansion: ReturnType<typeof createSpaceExpansionLayer>;
  setThrottle: (value: number) => void;
  setFocused: (value: boolean) => void;
  tick: (deltaTime: number) => void;
  syncFromApi: (payload: Record<string, unknown>) => void;
};

const defaultEngine: EngineTelemetry = {
  fuelStockpileUg: 48.5,
  penningTrapIntegrityPct: 99.99995,
  containmentBreach: false,
  annihilationRateNgPerS: 0,
  exhaustVelocityBeta: 0,
  specificImpulseS: 0,
  thrustNewtons: 0,
  thermalLoadMw: 0,
  gammaFluxSvPerS: 0,
  pionRadiationMevPerS: 0,
};

const defaultExpansion: ExpansionTelemetry = {
  scaleFactor: 1,
  positionMpc: 0.42,
  properVelocityKmS: 0,
  recessionVelocityKmS: 0,
  totalExpansionVelocityKmS: 0,
  spatialWarpingPct: 0,
  distanceToFinalDimensionMpc: 13_800,
  finalDimensionReached: false,
  coordinateShift: { x: 0, y: 0, z: 0 },
};

function mapEngine(raw: Record<string, unknown>): EngineTelemetry {
  return {
    fuelStockpileUg: Number(raw.fuelStockpileUg ?? 0),
    penningTrapIntegrityPct: Number(raw.penningTrapIntegrityPct ?? 0),
    containmentBreach: Boolean(raw.containmentBreach),
    annihilationRateNgPerS: Number(raw.annihilationRateNgPerS ?? 0),
    exhaustVelocityBeta: Number(raw.exhaustVelocityBeta ?? 0),
    specificImpulseS: Number(raw.specificImpulseS ?? 0),
    thrustNewtons: Number(raw.thrustNewtons ?? 0),
    thermalLoadMw: Number(raw.thermalLoadMw ?? 0),
    gammaFluxSvPerS: Number(raw.gammaFluxSvPerS ?? 0),
    pionRadiationMevPerS: Number(raw.pionRadiationMevPerS ?? 0),
  };
}

function mapExpansion(raw: Record<string, unknown>): ExpansionTelemetry {
  const shift = (raw.coordinateShift as Record<string, number>) ?? {};
  return {
    scaleFactor: Number(raw.scaleFactor ?? 1),
    positionMpc: Number(raw.positionMpc ?? 0),
    properVelocityKmS: Number(raw.properVelocityKmS ?? 0),
    recessionVelocityKmS: Number(raw.recessionVelocityKmS ?? 0),
    totalExpansionVelocityKmS: Number(raw.totalExpansionVelocityKmS ?? 0),
    spatialWarpingPct: Number(raw.spatialWarpingPct ?? 0),
    distanceToFinalDimensionMpc: Number(raw.distanceToFinalDimensionMpc ?? 0),
    finalDimensionReached: Boolean(raw.finalDimensionReached),
    coordinateShift: {
      x: Number(shift.x ?? 0),
      y: Number(shift.y ?? 0),
      z: Number(shift.z ?? 0),
    },
  };
}

export const useHelixDeltaStore = create<HelixDeltaState>((set, get) => ({
  throttle: 0.65,
  focused: false,
  engine: defaultEngine,
  expansion: defaultExpansion,
  lastTickAt: Date.now(),
  _engine: createAntimatterEngineV5(),
  _expansion: createSpaceExpansionLayer(),

  setThrottle: (value) => set({ throttle: Math.max(0, Math.min(1, value)) }),

  setFocused: (value) => set({ focused: value }),

  tick: (deltaTime) => {
    const { throttle, _engine, _expansion } = get();
    const result = _engine.updateEngineState(deltaTime, throttle);
    const engineRaw = _engine.getState();
    _expansion.updateExpansion(deltaTime, {
      thrustNewtons: result.thrustNewtons,
      exhaustVelocityBeta: engineRaw.exhaustVelocityBeta,
    });
    const expansionRaw = _expansion.getState();
    set({
      engine: mapEngine(engineRaw),
      expansion: mapExpansion(expansionRaw),
      lastTickAt: Date.now(),
    });
  },

  syncFromApi: (payload) => {
    const engine = mapEngine((payload.engine as Record<string, unknown>) ?? {});
    const expansion = mapExpansion((payload.expansion as Record<string, unknown>) ?? {});
    set({
      throttle: Number(payload.throttle ?? get().throttle),
      engine,
      expansion,
      lastTickAt: Date.now(),
    });
  },
}));
