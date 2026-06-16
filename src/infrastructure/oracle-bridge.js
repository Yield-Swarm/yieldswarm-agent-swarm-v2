// src/infrastructure/oracle-bridge.js
'use strict';

const { HardenedAuditEngine } = require('./entropy-core');

class TelemetryValidationBridge {
  constructor() {
    this.auditEngine = new HardenedAuditEngine();
  }

  processMetricPulse(pillarContext, realTimeMetrics) {
    try {
      if (!pillarContext || !realTimeMetrics) {
        return { status: 'FAILOVER_TRIGGERED', error: 'Missing essential data blocks.' };
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
        return {
          status: 'SUCCESS',
          stateAnchor: auditResult.blockVerificationHash,
          msg: `Pillar context verified at window depth ${auditResult.entropyWindowDepth}`,
        };
      }

      return { status: 'FAILOVER_TRIGGERED', error: 'Cryptographic validation failed.' };
    } catch (error) {
      return { status: 'FAILOVER_TRIGGERED', error: error.message };
    }
  }
}

module.exports = { TelemetryValidationBridge };
