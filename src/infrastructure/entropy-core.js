// src/infrastructure/entropy-core.js
'use strict';

const crypto = require('crypto');
const { SolenoidStateEngine } = require('./solenoid-engine');

class MultiLingualSolenoidEngine extends SolenoidStateEngine {
  constructor() {
    super();
    this.currentPillarIndex = 0;
    this.totalPillars = 14;
    this.difficultyTarget = '0000';
  }

  verifyMultilingualProof(pillarId, runTimeLanguage, blockData, nonce) {
    if (!pillarId || !runTimeLanguage || !blockData) {
      return { success: false, computedHash: '' };
    }
    const contextPrefix = `PILLAR_${pillarId}_LANG_${runTimeLanguage.toUpperCase()}`;
    const sanitizedBlock = this.particilizeRawString(
      typeof blockData === 'string' ? blockData : JSON.stringify(blockData),
    );
    const payloadToHash = `${contextPrefix}_${sanitizedBlock}_${nonce}_${this.stateChainHash}`;

    let evaluationHash = crypto.createHash('sha256').update(payloadToHash).digest('hex');
    if (runTimeLanguage === 'cuda' || runTimeLanguage === 'rust') {
      evaluationHash = crypto.createHash('sha256').update(evaluationHash).digest('hex');
    }

    const isValidProof = evaluationHash.startsWith(this.difficultyPrefix);
    if (isValidProof) {
      this.stateChainHash = crypto
        .createHash('sha256')
        .update(evaluationHash + this.stateChainHash)
        .digest('hex');
    }

    return { success: isValidProof, computedHash: evaluationHash };
  }

  incrementSolenoidLoop() {
    this.currentPillarIndex = (this.currentPillarIndex + 1) % this.totalPillars;
  }
}

class RosettaStoneLanguageCore {
  constructor(extraDictionary = {}) {
    this.dictionary = {
      D1_VAULT_LOCK: {
        en: 'Vault state secured. Cryptographic isolation active.',
        zh: '金库状态已锁定。加密隔离已激活。',
        hi: 'तिजोरी की स्थिति सुरक्षित। क्रिप्टोग्राफिक अलगाव सक्रिय।',
        es: 'Estado de la bóveda asegurado. Aislamiento criptográfico activo.',
        ar: 'تم تأمين حالة الخزنة. العزل التشفيري نشط.',
        fr: 'État du coffre-fort sécurisé. Isolement cryptographique actif.',
        ja: '金庫の状態は保護されています。暗号化分離が有効です。',
        de: 'Tresorstatus gesichert. Kryptografische Isolation aktiv.',
      },
      E1_THERMAL_OVERLOAD: {
        en: 'Thermal critical ceiling reached. Shifting node priority.',
        zh: '达到热临界上限。正在转移节点优先级。',
        hi: 'थर्मल क्रिटिकल सीमा पार। नोड प्राथमिकता बदली जा रही है।',
        es: 'Techo térmico crítico alcanzado. Cambiando prioridad del nodo.',
        ar: 'تم الوصول إلى الحد الحراري الحرج. يتم تغيير أولوية العقدة.',
        fr: 'Plafond thermique critique atteint. Modification de la priorité du nœud.',
        ja: '熱的限界に達しました。ノードの優先度を変更しています。',
        de: 'Kritische thermische Obergrenze erreicht. Knotenpriorität wird verschoben.',
      },
      TREASURY_SPLIT_5015155: {
        en: 'Great Delta split: Core 50% · Growth 30% · Insurance 15% · Ops 5%',
        zh: 'Great Delta 分配：核心 50% · 增长 30% · 保险 15% · 运营 5%',
      },
      ...extraDictionary,
    };
    this._loadPillarPack();
  }

  _loadPillarPack() {
    try {
      const fs = require('fs');
      const path = require('path');
      const packPath = path.join(__dirname, '..', '..', 'config', 'helix', 'rosetta-pillars.json');
      if (!fs.existsSync(packPath)) return;
      const pack = JSON.parse(fs.readFileSync(packPath, 'utf8'));
      if (pack.pillars) Object.assign(this.dictionary, pack.pillars);
      if (pack.treasury_split) this.dictionary.TREASURY_SPLIT_5015155 = pack.treasury_split;
    } catch {
      /* optional pack */
    }
  }

  /** Translate pillar id 1-14 to localized label. */
  translatePillar(pillarId, targetLang = 'en') {
    const key = `P${String(pillarId).padStart(2, '0')}_${this._pillarKey(pillarId)}`;
    return this.translate(key, targetLang);
  }

  _pillarKey(id) {
    const keys = [
      'GREEK_VAULTS', 'INFRA_ORACLES', 'ZK_MAYHEM', 'GPU_WORKERS', 'ARENA',
      'CROSS_CHAIN', 'TESLA_FLEET', 'EMISSION', 'AGENTSWARM', 'SECURITY_MPC',
      'TELEMETRY', 'GOVERNANCE', 'TREASURY_YIELD', 'VALHALLA',
    ];
    return keys[id - 1] || 'UNKNOWN';
  }

  translate(textCode, targetLang = 'en') {
    const cleanLang = targetLang.toLowerCase();
    if (!this.dictionary[textCode]) return `TRANSLATION_MISSING: ${textCode}`;
    return this.dictionary[textCode][cleanLang] || this.dictionary[textCode].en;
  }
}

class SymbioticEvolutionEngine {
  constructor() {
    this.generation = 1;
    this.mutationRate = 0.05;
    this.genePool = ['sha256', 'double-sha256', 'tensor-matrix'];
    this.activeGene = 'sha256';
    this.fitnessHistory = [];
  }

  evaluateAndMutate(telemetry, processingSpeed) {
    if (!telemetry || typeof processingSpeed !== 'number') return null;

    const currentFitness = processingSpeed / (telemetry.gpu_temperature || 1);
    this.fitnessHistory.push(currentFitness);

    let structuralShiftOccurred = false;
    let anomalyReport = 'STABLE_METRIC_RESONANCE';

    if (this.fitnessHistory.length > 10) {
      const averageFitness =
        this.fitnessHistory.slice(-10).reduce((a, b) => a + b, 0) / 10;

      if (currentFitness < averageFitness * 0.85) {
        this.generation++;
        this.mutationRate = Math.min(this.mutationRate * 1.2, 0.5);
        const structuralIndex = Math.floor(Math.random() * this.genePool.length);
        this.activeGene = this.genePool[structuralIndex];
        structuralShiftOccurred = true;
        anomalyReport = `EVOLUTIONARY_MUTATION_TRIGGERED_GEN_${this.generation}`;
      } else {
        this.mutationRate = Math.max(this.mutationRate * 0.95, 0.01);
      }
    }

    return {
      generationId: this.generation,
      activeAlgorithmTrack: this.activeGene,
      mutationProbability: parseFloat(this.mutationRate.toFixed(4)),
      structuralShiftOccurred,
      systemLogCode: anomalyReport,
    };
  }
}

class OmniDimensionalSafetyCanopy {
  constructor() {
    this.globalSafetyRating = 1.0;
    this.activeMitigationNodeCount = 0;
  }

  evaluateSystemHealth(matrixTelemetry, activeWorkloadDensity) {
    if (!matrixTelemetry) return { status: 'ERROR', msg: 'Telemetry missing.' };

    const hardwareTemp = matrixTelemetry.gpu_temperature || 0;
    const vramAllocated = matrixTelemetry.vram_allocated_bytes || 0;

    let protectionTriggered = false;
    let defensiveActionCode = 'SYSTEM_OPTIMAL_STABILITY_BOUND';

    if (
      hardwareTemp > 80 ||
      vramAllocated > 29_500_000_000 ||
      activeWorkloadDensity > 560
    ) {
      this.globalSafetyRating = Math.max(this.globalSafetyRating - 0.1, 0.4);
      this.activeMitigationNodeCount++;
      protectionTriggered = true;
      defensiveActionCode = 'ACTIVE_DEFENSIVE_SHIELDING_TRIGGERED';
    } else {
      this.globalSafetyRating = Math.min(this.globalSafetyRating + 0.05, 1.0);
      if (this.activeMitigationNodeCount > 0) this.activeMitigationNodeCount--;
    }

    return {
      safetyMetricIndex: parseFloat(this.globalSafetyRating.toFixed(2)),
      activeMitigationNodes: this.activeMitigationNodeCount,
      shieldingActive: protectionTriggered,
      systemLogCode: defensiveActionCode,
      timestamp: Date.now(),
    };
  }
}

class TeslaMeshEntropyCore {
  constructor() {
    this.fleetNodes = new Map();
    this.resonanceTarget = 60.0;
  }

  ingestFleetTelemetry(vin, telemetry) {
    if (!vin || !telemetry || typeof telemetry.battery_level === 'undefined') {
      return null;
    }

    const currentFrequency = telemetry.grid_frequency || 60.0;
    const resonanceDelta = Math.abs(this.resonanceTarget - currentFrequency);
    const computeWeight =
      (telemetry.battery_level / 100) * (telemetry.outside_temp ? 1.1 : 1.0);

    const nodeState = {
      vinHash: crypto.createHash('sha256').update(vin).digest('hex'),
      metrics: {
        soc: telemetry.battery_level,
        powerDraw: telemetry.power_draw_kw || 0,
        driveState: telemetry.shift_state || 'P',
        resonanceFactor: parseFloat((1.0 - resonanceDelta).toFixed(4)),
      },
      computeWeight: parseFloat(computeWeight.toFixed(2)),
      timestamp: telemetry.timestamp || Date.now(),
    };

    this.fleetNodes.set(nodeState.vinHash, nodeState);

    const seedPayload = `${nodeState.vinHash}${nodeState.metrics.soc}${nodeState.metrics.resonanceFactor}`;
    const blockVerificationHash = crypto.createHash('sha256').update(seedPayload).digest('hex');

    return {
      nodeRegistered: true,
      allocatedComputeWeight: nodeState.computeWeight,
      blockVerificationHash: '0x' + blockVerificationHash.slice(0, 32),
    };
  }
}

class HardenedAuditEngine {
  constructor() {
    this.stateChainHash = crypto.createHash('sha256').update('YIELDSWARM_GENESIS_ROOT').digest('hex');
    this.entropyLogWindow = [];
    this.MAX_WINDOW_CAPACITY = 64;
  }

  registerExecutionBlock(executionEvent, hardwareTelemetry) {
    if (!executionEvent || !hardwareTelemetry) {
      throw new Error('AUDIT_EXCEPTION: Missing core parameters.');
    }
    const structuredLog = {
      tenantHash: executionEvent.tenantHash || 'ANONYMOUS',
      actionHash: crypto
        .createHash('sha256')
        .update(JSON.stringify(executionEvent.payload || {}))
        .digest('hex'),
      hardwareMetrics: {
        vram: Math.round(hardwareTelemetry.vram_used_bytes || 0),
        temp: Math.round(hardwareTelemetry.gpu_temperature || 0),
        tokensPerSec: Math.round(hardwareTelemetry.tokens_per_sec || 0),
      },
      timestamp: hardwareTelemetry.timestamp || Date.now(),
      parentStateHash: this.stateChainHash,
    };

    this.entropyLogWindow.push(structuredLog);
    if (this.entropyLogWindow.length > this.MAX_WINDOW_CAPACITY) {
      this.entropyLogWindow.shift();
    }

    const serialized = JSON.stringify(structuredLog) + this.stateChainHash;
    this.stateChainHash = crypto.createHash('sha256').update(serialized).digest('hex');

    return {
      blockVerificationHash: this.stateChainHash,
      entropyWindowDepth: this.entropyLogWindow.length,
      integrityConfirmed: true,
    };
  }
}

const { EntropyCore } = require('./zk-entropy-core');

module.exports = {
  MultiLingualSolenoidEngine,
  RosettaStoneLanguageCore,
  SymbioticEvolutionEngine,
  OmniDimensionalSafetyCanopy,
  TeslaMeshEntropyCore,
  HardenedAuditEngine,
  EntropyCore,
};
