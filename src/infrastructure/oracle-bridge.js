// src/infrastructure/oracle-bridge.js
'use strict';

const { HardenedAuditEngine, TeslaMeshEntropyCore } = require('./entropy-core');

/** Great Delta 50/30/15/5 treasury buckets (bps). */
const TREASURY_BPS = [5000, 3000, 1500, 500];
const BPS_DENOM = 10_000;

class TelemetryValidationBridge {
  constructor() {
    this.auditEngine = new HardenedAuditEngine();
    this.teslaMesh = new TeslaMeshEntropyCore();
  }

  /**
   * Link ZK entropy seed + optional Tesla fleet weight to non-dilutive treasury yield estimate.
   * @param {number} grossYieldUsd
   * @param {string} blockVerificationHash
   */
  computeTreasuryYieldSplit(grossYieldUsd, blockVerificationHash) {
    const amount = Number(grossYieldUsd) || 0;
    let allocated = 0;
    const buckets = ['coreTreasury', 'growthTreasury', 'insuranceTreasury', 'opsTreasury'];
    const splits = TREASURY_BPS.map((bps, i) => {
      const share =
        i === buckets.length - 1 ? amount - allocated : Math.floor((amount * bps) / BPS_DENOM);
      allocated += share;
      return { bucket: buckets[i], bps, usd: share };
    });
    return {
      grossYieldUsd: amount,
      splitPolicy: '50/30/15/5',
      splits,
      entropyAnchor: blockVerificationHash,
      nonDilutive: true,
    };
  }

  processMetricPulse(pillarContext, realTimeMetrics) {
    try {
      if (!pillarContext || !realTimeMetrics) {
        return { status: 'FAILOVER_TRIGGERED', error: 'Missing essential data blocks.' };
      }

      if (realTimeMetrics.vin || realTimeMetrics.battery_level !== undefined) {
        this.teslaMesh.ingestFleetTelemetry(realTimeMetrics.vin || 'FLEET_NODE', realTimeMetrics);
      }

      const executionEvent = {
        tenantHash: pillarContext.namespaceHash || 'SYSTEM_ORCHESTRATOR',
        payload: {
          pillarId: pillarContext.id,
          status: 'MAYHEM_VALIDATION_ACTIVE',
        },
      };

      const auditResult = this.auditEngine.registerExecutionBlock(
        executionEvent,
        realTimeMetrics
      );

      if (auditResult.integrityConfirmed && auditResult.blockVerificationHash) {
        const yieldHint = this.computeTreasuryYieldSplit(
          realTimeMetrics.projected_yield_usd || 0,
          auditResult.blockVerificationHash
        );
        return {
          status: 'SUCCESS',
          stateAnchor: auditResult.blockVerificationHash,
          msg: `Pillar context verified at window depth ${auditResult.entropyWindowDepth}`,
          treasuryYield: yieldHint,
        };
      }

      return { status: 'FAILOVER_TRIGGERED', error: 'Cryptographic validation failed.' };
    } catch (error) {
      return { status: 'FAILOVER_TRIGGERED', error: error.message };
    }
  }
}

module.exports = { TelemetryValidationBridge };
