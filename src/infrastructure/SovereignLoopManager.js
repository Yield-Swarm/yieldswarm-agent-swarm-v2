/**
 * Sovereign Loop Engine v1.1.0-RU
 * ─────────────────────────────────────────────────────────────────────────────
 * Autonomous background service for the YieldSwarm multichain stack:
 *   • Nexus (Solenoid 1)
 *   • Helix Delta (Solenoid 2)
 *   • Shadow (Solenoid 3)
 *   • IoTeX (DePIN / MachineFi)
 *
 * Three parallel loops:
 *   1. Economic   — treasury health + Nexus reserve rebalancing
 *   2. Replication — surplus-driven swarm agent / node provisioning
 *   3. Self-heal  — anomaly isolation, checkpoint rollback, telemetry restart
 */

'use strict';

const VERSION = '1.1.0-RU';

/** Display states for TV dashboard and API consumers. */
const LOOP_STATES = {
  ACTIVE: 'Active Loop Running',
  REBALANCE: 'Rebalancing Funds',
  REPLICATE: 'Deploying Replica',
  PATCH: 'Executing Self-Heal Patch',
};

const MAX_LOGS = 200;

/** Per-chain liquidity floor (USD) before Nexus reserve top-up. */
const DEFAULT_TREASURY_THRESHOLDS = {
  nexus: 250_000,
  helix: 180_000,
  shadow: 90_000,
  iotex: 25_000,
};

/** Total NAV surplus % that triggers replication. */
const DEFAULT_REPLICATION_THRESHOLD = 72;

function timestamp() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

/** Monospace-friendly log line for dark TV terminals. */
function createLog(type, message) {
  const pad = type.padEnd(8, ' ');
  return {
    type,
    message: `[${pad}] ${message}`,
    timestamp: timestamp(),
  };
}

function assertSovereignConfig() {
  const vault = process.env.VAULT_SECRET_TOKEN;
  const loopKey = process.env.SOVEREIGN_LOOP_KEY;
  const missing = [];
  if (!vault || !String(vault).trim()) missing.push('VAULT_SECRET_TOKEN');
  if (!loopKey || !String(loopKey).trim()) missing.push('SOVEREIGN_LOOP_KEY');
  if (missing.length) {
    throw new Error(
      `Sovereign Loop Engine configuration error: missing ${missing.join(', ')}. ` +
        'Inject via HashiCorp Vault before starting the background service.',
    );
  }
}

class SovereignLoopManager {
  /**
   * @param {{ skipAuth?: boolean, replicationThreshold?: number, treasuryThresholds?: object }} [options]
   */
  constructor(options = {}) {
    if (!options.skipAuth) {
      assertSovereignConfig();
    }

    this.version = VERSION;
    this.currentState = LOOP_STATES.ACTIVE;
    this.logs = [
      createLog('System', `Sovereign Loop Engine ${VERSION} initialized`),
      createLog('System', 'Economic · Replication · Self-heal loops armed'),
    ];

    this.treasuries = { nexus: 0, helix: 0, shadow: 0, iotex: 0 };
    this.totalTreasury = 0;
    this.penningTrapIntegrity = 99.99995;
    this.replicationSurplus = 0;
    this.replicationThreshold =
      options.replicationThreshold ??
      Number(process.env.SOVEREIGN_REPLICATION_THRESHOLD || DEFAULT_REPLICATION_THRESHOLD);
    this.treasuryThresholds = {
      ...DEFAULT_TREASURY_THRESHOLDS,
      ...(options.treasuryThresholds || {}),
    };

    this._tick = 0;
    this._forcedState = null;
    this._forcedStateUntil = 0;
    this._intervalId = null;
    this._lastCheckpoint = { treasuries: { ...this.treasuries }, integrity: this.penningTrapIntegrity };
    this._isolatedChannels = new Set();
  }

  // ─── Loop 1: Economic (treasury rebalancing) ───────────────────────────────

  /**
   * Monitors four-chain treasury liquidity and triggers Nexus reserve transfers.
   * @returns {{ healthy: boolean, actions: string[] }}
   */
  evaluateTreasuryHealth() {
    const actions = [];
    let healthy = true;
    const reserve = this.treasuries.nexus;

    for (const [chain, balance] of Object.entries(this.treasuries)) {
      const floor = this.treasuryThresholds[chain] ?? 0;
      if (balance < floor) {
        healthy = false;
        const deficit = floor - balance;
        if (chain !== 'nexus' && reserve > deficit * 1.2) {
          const transfer = Math.min(deficit, Math.floor(reserve * 0.15));
          this.treasuries.nexus -= transfer;
          this.treasuries[chain] += transfer;
          actions.push(`Nexus→${chain} +$${transfer.toLocaleString()} (floor $${floor.toLocaleString()})`);
          this._pushLog('Economic', `Rebalance ${chain}: transferred $${transfer.toLocaleString()} from Nexus reserve`);
        } else {
          actions.push(`${chain} below floor ($${balance.toLocaleString()} < $${floor.toLocaleString()})`);
          this._pushLog('Warning', `Treasury ${chain} under-liquid: $${balance.toLocaleString()}`);
        }
      }
    }

    if (actions.length) {
      this.currentState = LOOP_STATES.REBALANCE;
    }

    return { healthy, actions };
  }

  // ─── Loop 2: Replication (autonomous scaling) ────────────────────────────

  /**
   * Tracks aggregate reserve surplus and provisions swarm agents / nodes.
   * @returns {{ scale: boolean, deployment?: object }}
   */
  checkReplicationStatus() {
    const targetAgents = Number(process.env.AGENT_COUNT_TOTAL || 10080);
    const activeAgents = Math.round((this.replicationSurplus / 100) * targetAgents);

    if (this.replicationSurplus < this.replicationThreshold) {
      return { scale: false };
    }

    const shardId = this._tick % Number(process.env.CRON_SHARD_COUNT || 120);
    const deployment = {
      shardId,
      region: process.env.AZURE_PROD_LOCATION || 'Australia East',
      provider: 'akash',
      agentsRequested: Math.min(84, targetAgents - activeAgents),
      env: process.env.TARGET_ENV || 'production',
    };

    this.currentState = LOOP_STATES.REPLICATE;
    this._pushLog(
      'Replica',
      `Deploy shard-${shardId} @ ${deployment.region} · +${deployment.agentsRequested} agents · surplus ${this.replicationSurplus.toFixed(1)}%`,
    );

    return { scale: true, deployment };
  }

  // ─── Loop 3: Self-heal (patch cycle) ───────────────────────────────────────

  /**
   * Detects anomalies, isolates faulty channels, rolls back, restarts telemetry.
   * @returns {{ patched: boolean, isolated: string[] }}
   */
  triggerPatchCycle() {
    const isolated = [];
    const anomalies = [];

    if (this.penningTrapIntegrity < 99.99) {
      anomalies.push('penning_trap_integrity');
    }
    for (const [chain, balance] of Object.entries(this.treasuries)) {
      if (balance <= 0 && chain !== 'shadow') {
        anomalies.push(`treasury_${chain}_zero`);
      }
    }

    if (!anomalies.length) {
      return { patched: false, isolated };
    }

    this.currentState = LOOP_STATES.PATCH;

    for (const channel of anomalies) {
      this._isolatedChannels.add(channel);
      isolated.push(channel);
      this._pushLog('Critical', `Isolated channel: ${channel}`);
    }

    // Roll back to last stable checkpoint without stopping the full system.
    this.treasuries = { ...this._lastCheckpoint.treasuries };
    this.penningTrapIntegrity = Math.min(
      99.99999,
      this._lastCheckpoint.integrity + 0.0015,
    );

    this._pushLog('Patch', 'Checkpoint rollback applied — telemetry stream restarting');
    this._pushLog('Patch', `Channels isolated: ${isolated.join(', ')}`);

    // Clear isolation after simulated recovery window.
    if (this._tick % 5 === 0) {
      this._isolatedChannels.clear();
    }

    return { patched: true, isolated };
  }

  // ─── Background service ────────────────────────────────────────────────────

  /** Runs one full evaluation cycle across all three loops. */
  runCycle(overlay = {}) {
    if (overlay && Object.keys(overlay).length) {
      this.ingestTelemetry(overlay);
    }

    const economic = this.evaluateTreasuryHealth();
    const replication = this.checkReplicationStatus();
    const heal = this.triggerPatchCycle();

    if (!economic.actions.length && !replication.scale && !heal.patched) {
      this.currentState = this._resolveNominalState();
    }

    if (this.penningTrapIntegrity >= 99.99 && economic.healthy) {
      this._lastCheckpoint = {
        treasuries: { ...this.treasuries },
        integrity: this.penningTrapIntegrity,
      };
    }

    return { economic, replication, heal, state: this.currentState };
  }

  /**
   * Starts the sovereign loop background service.
   * @param {number} [intervalMs]
   * @param {() => Promise<object>|object} [telemetryProvider]
   */
  startBackgroundService(intervalMs = Number(process.env.SOVEREIGN_LOOP_INTERVAL || 15) * 1000, telemetryProvider) {
    assertSovereignConfig();
    if (this._intervalId) return;

    this._pushLog('System', `Background service started · interval ${intervalMs}ms`);
    this._intervalId = setInterval(async () => {
      try {
        const overlay = telemetryProvider ? await telemetryProvider() : {};
        this.runCycle(overlay);
      } catch (err) {
        this._pushLog('Critical', `Cycle error: ${err.message}`);
      }
    }, intervalMs);

    if (this._intervalId.unref) this._intervalId.unref();
  }

  stopBackgroundService() {
    if (this._intervalId) {
      clearInterval(this._intervalId);
      this._intervalId = null;
      this._pushLog('System', 'Background service stopped');
    }
  }

  // ─── Telemetry ingest ────────────────────────────────────────────────────────

  ingestTelemetry(overlay = {}) {
    const sovereign = overlay.sovereign || {};
    const helix = overlay.helix || {};
    const iotex = overlay.iotex || sovereign.iotex || {};
    const live = sovereign.live_overlay || {};

    const nav = Number(sovereign.net_worth_usd ?? sovereign.vault_usd ?? 0);
    const nexusUsd = Number(sovereign.treasury_usd ?? nav * 0.35);
    const helixUsd = Number(helix.treasuryNavUsd ?? nav * 0.28);
    const shadowUsd = Math.max(0, (nav - nexusUsd - helixUsd) * 0.12);
    const iotexUsd = Number(iotex.treasury_usd ?? iotex.balanceUsd ?? nav * 0.05);

    this.treasuries = {
      nexus: Math.round(nexusUsd),
      helix: Math.round(helixUsd),
      shadow: Math.round(shadowUsd),
      iotex: Math.round(iotexUsd),
    };
    this.totalTreasury = Math.round(
      nav || nexusUsd + helixUsd + shadowUsd + iotexUsd,
    );

    const workers = Number(sovereign.counts?.workers ?? live.akash?.workers ?? 0);
    const agents = Number(sovereign.counts?.agents ?? 84);
    const targetAgents = Number(process.env.AGENT_COUNT_TOTAL || 10080);
    this.replicationSurplus = Math.min(
      100,
      ((workers * agents) / Math.max(1, targetAgents)) * 100,
    );

    if (helix.engine?.penningTrapIntegrityPct != null) {
      this.penningTrapIntegrity = Number(helix.engine.penningTrapIntegrityPct);
    }

    this._tick += 1;

    if (this._forcedState && Date.now() < this._forcedStateUntil) {
      this.currentState = this._forcedState;
      return;
    }
    this._forcedState = null;
  }

  // ─── Manual overrides (dashboard / API) ─────────────────────────────────────

  forceRebalance() {
    this._forcedState = LOOP_STATES.REBALANCE;
    this._forcedStateUntil = Date.now() + 8000;
    this.currentState = this._forcedState;
    this.evaluateTreasuryHealth();
    this._pushLog('Economic', 'Manual override: economic balancing forced');
    return this.snapshot();
  }

  forceReplicate() {
    this._forcedState = LOOP_STATES.REPLICATE;
    this._forcedStateUntil = Date.now() + 8000;
    this.currentState = this._forcedState;
    this.replicationSurplus = Math.min(100, this.replicationSurplus + 8);
    this.checkReplicationStatus();
    this._pushLog('Replica', 'Manual override: replication loop engaged');
    return this.snapshot();
  }

  triggerPatch() {
    return this.triggerPatchCycleManual();
  }

  triggerPatchCycleManual() {
    this._forcedState = LOOP_STATES.PATCH;
    this._forcedStateUntil = Date.now() + 10000;
    this.currentState = this._forcedState;
    this.penningTrapIntegrity = Math.min(99.99999, this.penningTrapIntegrity + 0.002);
    this.triggerPatchCycle();
    this._pushLog('Patch', 'Manual override: self-heal patch cycle triggered');
    return this.snapshot();
  }

  snapshot() {
    return {
      version: this.version,
      currentState: this.currentState,
      logs: [...this.logs],
      treasuries: { ...this.treasuries },
      totalTreasury: this.totalTreasury,
      penningTrapIntegrity: this.penningTrapIntegrity,
      replicationSurplus: this.replicationSurplus,
      replicationThreshold: this.replicationThreshold,
      isolatedChannels: [...this._isolatedChannels],
      backgroundRunning: Boolean(this._intervalId),
    };
  }

  _resolveNominalState() {
    return LOOP_STATES.ACTIVE;
  }

  _pushLog(type, message) {
    this.logs.unshift(createLog(type, message));
    if (this.logs.length > MAX_LOGS) {
      this.logs.length = MAX_LOGS;
    }
  }
}

let manager = null;

function getSovereignLoopManager() {
  if (!manager) {
    const skip = process.env.NODE_ENV === 'test' || process.env.SOVEREIGN_LOOP_SKIP_AUTH === '1';
    manager = new SovereignLoopManager({ skipAuth: skip });
  }
  return manager;
}

function resetSovereignLoopManager() {
  if (manager) manager.stopBackgroundService();
  const skip = process.env.NODE_ENV === 'test' || process.env.SOVEREIGN_LOOP_SKIP_AUTH === '1';
  manager = new SovereignLoopManager({ skipAuth: skip });
  return manager;
}

module.exports = {
  VERSION,
  LOOP_STATES,
  SovereignLoopManager,
  assertSovereignConfig,
  getSovereignLoopManager,
  resetSovereignLoopManager,
};
