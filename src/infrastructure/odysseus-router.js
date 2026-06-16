// src/infrastructure/odysseus-router.js
'use strict';

const crypto = require('crypto');
const {
  MultiLingualSolenoidEngine,
  RosettaStoneLanguageCore,
  SymbioticEvolutionEngine,
  OmniDimensionalSafetyCanopy,
  TeslaMeshEntropyCore,
} = require('./entropy-core');

class QuadrilateralSolenoidRouter {
  constructor() {
    this.contexts = new Map();
    this.maxHistoryWindow = 32;
    this.solenoidEngine = new MultiLingualSolenoidEngine();
    this.rosetta = new RosettaStoneLanguageCore();
    this.evolutionEngine = new SymbioticEvolutionEngine();
    this.canopy = new OmniDimensionalSafetyCanopy();
    this.teslaMesh = new TeslaMeshEntropyCore();
  }

  async processAxisMatrix(
    tenantConfig,
    pipelinePayloads,
    rawHardwareTelemetry,
    targetLocale = 'en'
  ) {
    if (
      !tenantConfig ||
      !tenantConfig.id ||
      !Array.isArray(pipelinePayloads) ||
      pipelinePayloads.length !== 14
    ) {
      throw new Error(
        'X_AXIS_ISOLATION_FAULT: Invalid tenant profile or incomplete 14-pillar matrix.'
      );
    }

    const tenantHash = crypto.createHash('sha256').update(tenantConfig.id).digest('hex');
    if (!this.contexts.has(tenantHash)) {
      this.contexts.set(tenantHash, {
        history: [],
        tier: tenantConfig.tier || 1,
        initializedAt: Date.now(),
      });
    }
    const ctx = this.contexts.get(tenantHash);

    if (ctx.history.length > this.maxHistoryWindow) {
      ctx.history = ctx.history.slice(-Math.floor(this.maxHistoryWindow * 0.5));
    }

    if (tenantConfig.fleetVin && rawHardwareTelemetry) {
      this.teslaMesh.ingestFleetTelemetry(tenantConfig.fleetVin, {
        battery_level: rawHardwareTelemetry.battery_level ?? 80,
        grid_frequency: rawHardwareTelemetry.grid_frequency ?? 60.0,
        outside_temp: rawHardwareTelemetry.outside_temp ?? rawHardwareTelemetry.gpu_temperature,
        power_draw_kw: rawHardwareTelemetry.power_draw_kw ?? 0,
        shift_state: rawHardwareTelemetry.shift_state ?? 'P',
        timestamp: rawHardwareTelemetry.timestamp ?? Date.now(),
      });
    }

    const throughputSample = pipelinePayloads.length * 12.5;
    const evolutionStatus = this.evolutionEngine.evaluateAndMutate(
      rawHardwareTelemetry,
      throughputSample
    );
    const healthStatus = this.canopy.evaluateSystemHealth(
      rawHardwareTelemetry,
      pipelinePayloads.length
    );

    const executionPromises = pipelinePayloads.map(async (taskItem, index) => {
      const laneId = index + 1;
      const runtimeTarget = this.determineRuntimeTrack(laneId);

      const sanitizedPrompt = (taskItem.prompt || '')
        .replace(/[\x00-\x1F\x7F-\x9F]/g, '')
        .trim();

      const proofVerification = this.solenoidEngine.verifyMultilingualProof(
        laneId,
        runtimeTarget,
        JSON.stringify({ data: taskItem.data, input: sanitizedPrompt }),
        taskItem.nonce || 0
      );

      const logCode = proofVerification.success ? 'D1_VAULT_LOCK' : 'E1_THERMAL_OVERLOAD';
      const localizedMsg = this.rosetta.translate(logCode, targetLocale);

      let optimizedEndpoint = `LOCAL_BARE_METAL_AXIS_LANE_${laneId}`;
      if (healthStatus.shieldingActive && laneId >= 3) {
        optimizedEndpoint = 'MULTI_CLOUD_FAILOVER_ISOLATED_NODE';
      }

      return {
        laneId,
        runtime: runtimeTarget,
        verified: proofVerification.success,
        hashAnchor: proofVerification.computedHash,
        statusUpdate: localizedMsg,
        allocatedRoute: optimizedEndpoint,
        activeGeneTrack: evolutionStatus ? evolutionStatus.activeAlgorithmTrack : 'sha256',
        axisContext: {
          X_Layer: 'Namespace_Isolated',
          Y_Layer: 'Flow_Synchronized',
          Z_Layer:
            evolutionStatus && evolutionStatus.structuralShiftOccurred ? 'MUTATED' : 'NOMINAL',
          W_Layer: targetLocale,
        },
      };
    });

    const detailedMatrixResults = await Promise.all(executionPromises);
    this.solenoidEngine.incrementSolenoidLoop();

    ctx.history.push({
      role: 'system',
      timestamp: Date.now(),
      stateRoot: this.solenoidEngine.stateChainHash,
      evolutionGen: evolutionStatus ? evolutionStatus.generationId : 1,
    });

    return {
      layer: 'PDs1_QUADRILATERAL_AXIS_COMPLETE',
      safetyProfile: healthStatus,
      evolutionProfile: evolutionStatus,
      matrix: detailedMatrixResults,
    };
  }

  determineRuntimeTrack(laneId) {
    if (laneId === 3 || laneId === 10) return 'rust';
    if (laneId === 2 || laneId === 4) return 'cuda';
    return 'javascript';
  }
}

module.exports = { QuadrilateralSolenoidRouter };
