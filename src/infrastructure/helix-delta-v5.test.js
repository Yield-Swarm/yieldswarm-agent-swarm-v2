import { describe, expect, it } from 'vitest';
import {
  AntimatterEngineV5,
  updateEngineState,
  PENNING_CRITICAL_PCT,
  ISP_TARGET,
} from './AntimatterEngineV5.js';
import {
  SpaceExpansionLayer,
  scaleFactorAtTime,
  FINAL_DIMENSION_MPC,
} from './SpaceExpansionLayer.js';

describe('AntimatterEngineV5', () => {
  it('exposes fuel stockpile and penning trap integrity', () => {
    const engine = new AntimatterEngineV5();
    const state = engine.getState();
    expect(state.fuelStockpileUg).toBeGreaterThan(0);
    expect(state.penningTrapIntegrityPct).toBeGreaterThan(PENNING_CRITICAL_PCT);
  });

  it('consumes fuel and produces thrust at throttle', () => {
    const engine = new AntimatterEngineV5();
    const before = engine.getState().fuelStockpileUg;
    const result = engine.updateEngineState(1, 0.8);
    const after = engine.getState();
    expect(after.fuelStockpileUg).toBeLessThan(before);
    expect(result.thrustNewtons).toBeGreaterThan(0);
    expect(after.specificImpulseS).toBeGreaterThan(1_000_000);
    expect(after.specificImpulseS).toBeLessThanOrEqual(ISP_TARGET);
  });

  it('targets relativistic exhaust velocity between 0.3c and 0.94c', () => {
    const engine = new AntimatterEngineV5();
    engine.updateEngineState(0.5, 1);
    const beta = engine.getState().exhaustVelocityBeta;
    expect(beta).toBeGreaterThanOrEqual(0.3);
    expect(beta).toBeLessThanOrEqual(0.94);
  });

  it('triggers containment breach alarm below critical threshold', () => {
    const engine = new AntimatterEngineV5({
      initialState: { penningTrapIntegrityPct: PENNING_CRITICAL_PCT - 0.001 },
    });
    engine.updateEngineState(0.1, 0.5);
    expect(engine.getState().containmentBreach).toBe(true);
  });

  it('updateEngineState export mutates state object', () => {
    const state = new AntimatterEngineV5().getState();
    const next = updateEngineState(state, 0.5, 0.5);
    expect(next.clockCycles).toBe(1);
  });
});

describe('SpaceExpansionLayer', () => {
  it('computes monotonic scale factor', () => {
    expect(scaleFactorAtTime(0)).toBe(1);
    expect(scaleFactorAtTime(1e15)).toBeGreaterThan(1);
  });

  it('tracks proper vs recession velocity', () => {
    const layer = new SpaceExpansionLayer();
    layer.updateExpansion(1, { thrustNewtons: 50, exhaustVelocityBeta: 0.5 });
    const s = layer.getState();
    expect(s.properVelocityKmS).toBeGreaterThan(0);
    expect(s.recessionVelocityKmS).toBeGreaterThan(0);
    expect(s.totalExpansionVelocityKmS).toBeCloseTo(
      s.properVelocityKmS + s.recessionVelocityKmS,
      5,
    );
  });

  it('advances expansion state under sustained thrust', () => {
    const layer = new SpaceExpansionLayer();
    const start = layer.getState();
    for (let i = 0; i < 50; i++) {
      layer.updateExpansion(1, { thrustNewtons: 50_000, exhaustVelocityBeta: 0.7 });
    }
    const after = layer.getState();
    expect(after.properVelocityKmS).toBeGreaterThan(start.properVelocityKmS);
    expect(after.scaleFactor).toBeGreaterThan(start.scaleFactor);
    expect(after.cosmicTimeS).toBeGreaterThan(start.cosmicTimeS);
    expect(after.distanceToFinalDimensionMpc).toBeLessThanOrEqual(FINAL_DIMENSION_MPC);
  });
});
