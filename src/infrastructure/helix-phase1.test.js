import { describe, expect, it } from 'vitest';
import {
  MultiLingualSolenoidEngine,
  RosettaStoneLanguageCore,
  SymbioticEvolutionEngine,
  OmniDimensionalSafetyCanopy,
  TeslaMeshEntropyCore,
  HardenedAuditEngine,
} from './entropy-core.js';
import { QuadrilateralSolenoidRouter } from './odysseus-router.js';
import { TelemetryValidationBridge } from './oracle-bridge.js';

describe('MultiLingualSolenoidEngine', () => {
  it('rejects incomplete proof inputs', () => {
    const engine = new MultiLingualSolenoidEngine();
    expect(engine.verifyMultilingualProof(null, 'rust', 'data', 0).success).toBe(false);
  });

  it('cycles pillar index', () => {
    const engine = new MultiLingualSolenoidEngine();
    const start = engine.currentPillarIndex;
    engine.incrementSolenoidLoop();
    expect(engine.currentPillarIndex).toBe((start + 1) % 14);
  });
});

describe('RosettaStoneLanguageCore', () => {
  it('translates vault lock messages', () => {
    const rosetta = new RosettaStoneLanguageCore();
    expect(rosetta.translate('D1_VAULT_LOCK', 'en')).toContain('Vault');
    expect(rosetta.translate('D1_VAULT_LOCK', 'zh')).toContain('金库');
  });

  it('falls back to English for unknown locale', () => {
    const rosetta = new RosettaStoneLanguageCore();
    const msg = rosetta.translate('E1_THERMAL_OVERLOAD', 'xx');
    expect(msg).toContain('Thermal');
  });
});

describe('SymbioticEvolutionEngine', () => {
  it('returns null without valid telemetry', () => {
    const engine = new SymbioticEvolutionEngine();
    expect(engine.evaluateAndMutate(null, 100)).toBeNull();
  });

  it('tracks fitness over repeated samples', () => {
    const engine = new SymbioticEvolutionEngine();
    for (let i = 0; i < 12; i++) {
      engine.evaluateAndMutate({ gpu_temperature: 70 }, 175);
    }
    const result = engine.evaluateAndMutate({ gpu_temperature: 70 }, 175);
    expect(result).toHaveProperty('generationId');
    expect(result).toHaveProperty('activeAlgorithmTrack');
  });
});

describe('OmniDimensionalSafetyCanopy', () => {
  it('flags thermal overload', () => {
    const canopy = new OmniDimensionalSafetyCanopy();
    const health = canopy.evaluateSystemHealth(
      { gpu_temperature: 90, vram_allocated_bytes: 1_000_000_000 },
      100
    );
    expect(health.shieldingActive).toBe(true);
    expect(health.safetyMetricIndex).toBeLessThan(1.0);
  });

  it('recovers safety rating under nominal load', () => {
    const canopy = new OmniDimensionalSafetyCanopy();
    canopy.evaluateSystemHealth({ gpu_temperature: 90, vram_allocated_bytes: 0 }, 600);
    const recovered = canopy.evaluateSystemHealth(
      { gpu_temperature: 65, vram_allocated_bytes: 1_000_000_000 },
      100
    );
    expect(recovered.shieldingActive).toBe(false);
  });
});

describe('TeslaMeshEntropyCore', () => {
  it('registers fleet telemetry nodes', () => {
    const mesh = new TeslaMeshEntropyCore();
    const result = mesh.ingestFleetTelemetry('VIN123', {
      battery_level: 88,
      grid_frequency: 60.0,
      power_draw_kw: 12,
    });
    expect(result?.nodeRegistered).toBe(true);
    expect(result?.blockVerificationHash).toMatch(/^0x[0-9a-f]{32}$/);
  });
});

describe('HardenedAuditEngine', () => {
  it('chains execution blocks', () => {
    const audit = new HardenedAuditEngine();
    const first = audit.registerExecutionBlock(
      { tenantHash: 'T1', payload: { action: 'test' } },
      { gpu_temperature: 72, vram_used_bytes: 1e9, tokens_per_sec: 500 }
    );
    const second = audit.registerExecutionBlock(
      { tenantHash: 'T1', payload: { action: 'test2' } },
      { gpu_temperature: 73, vram_used_bytes: 1.1e9, tokens_per_sec: 510 }
    );
    expect(first.integrityConfirmed).toBe(true);
    expect(second.blockVerificationHash).not.toBe(first.blockVerificationHash);
    expect(second.entropyWindowDepth).toBe(2);
  });
});

describe('QuadrilateralSolenoidRouter', () => {
  function build14Pillars() {
    return Array.from({ length: 14 }, (_, i) => ({
      data: { lane: i + 1 },
      prompt: `pillar ${i + 1}`,
      nonce: 0,
    }));
  }

  it('throws on incomplete pillar matrix', async () => {
    const router = new QuadrilateralSolenoidRouter();
    await expect(
      router.processAxisMatrix({ id: 'tenant-a' }, [{ data: {} }], { gpu_temperature: 70 })
    ).rejects.toThrow('X_AXIS_ISOLATION_FAULT');
  });

  it('processes full 14-pillar matrix', async () => {
    const router = new QuadrilateralSolenoidRouter();
    const result = await router.processAxisMatrix(
      { id: 'tenant-a', tier: 2 },
      build14Pillars(),
      { gpu_temperature: 72, vram_allocated_bytes: 20_000_000_000 },
      'en'
    );
    expect(result.layer).toBe('PDs1_QUADRILATERAL_AXIS_COMPLETE');
    expect(result.matrix).toHaveLength(14);
    expect(result.safetyProfile).toHaveProperty('safetyMetricIndex');
  });
});

describe('TelemetryValidationBridge', () => {
  it('accepts valid metric pulses', () => {
    const bridge = new TelemetryValidationBridge();
    const result = bridge.processMetricPulse(
      { id: '3', namespaceHash: 'NS_3' },
      { gpu_temperature: 78, vram_used_bytes: 24_000_000_000 }
    );
    expect(result.status).toBe('SUCCESS');
    expect(result.stateAnchor).toMatch(/^[0-9a-f]{64}$/);
  });

  it('failovers on missing data', () => {
    const bridge = new TelemetryValidationBridge();
    expect(bridge.processMetricPulse(null, {}).status).toBe('FAILOVER_TRIGGERED');
  });
});
