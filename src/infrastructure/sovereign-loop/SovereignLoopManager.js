/**
 * Sovereign Loop Engine (v1.0.0-Beta)
 * Three autonomous self-healing loops across Nexus, Helix, Shadow, IoTeX.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');
const STATE_PATH = process.env.SOVEREIGN_LOOP_STATE ||
  path.join(REPO_ROOT, '.run', 'sovereign-loops.json');

export const LOOP_STATES = Object.freeze({
  IDLE: 'Active Loop Running',
  REBALANCING: 'Rebalancing Funds',
  REPLICATING: 'Deploying Replica',
  HEALING: 'Executing Self-Heal Patch',
  ERROR: 'Configuration Error',
});

const CHAINS = Object.freeze(['nexus', 'helix', 'shadow', 'iotex']);

function nowIso() {
  return new Date().toISOString();
}

function logEntry(phase, message, meta = {}) {
  return {
    ts: nowIso(),
    phase,
    message,
    ...meta,
  };
}

/**
 * @throws {Error} if required vault credentials are missing
 */
export function assertSovereignCredentials() {
  const vault = process.env.VAULT_SECRET_TOKEN || process.env.VAULT_TOKEN;
  const loopKey = process.env.SOVEREIGN_LOOP_KEY;
  const missing = [];
  if (!vault) missing.push('VAULT_SECRET_TOKEN or VAULT_TOKEN');
  if (!loopKey) missing.push('SOVEREIGN_LOOP_KEY');
  if (missing.length) {
    throw new Error(
      `Sovereign Loop configuration error: missing ${missing.join(', ')}. `
      + 'Inject from HashiCorp Vault before starting the daemon.',
    );
  }
  return { vaultConfigured: true, loopKeyConfigured: true };
}

export class SovereignLoopManager {
  constructor(options = {}) {
    this.treasuryThresholdUsd = options.treasuryThresholdUsd
      ?? Number(process.env.SOVEREIGN_TREASURY_THRESHOLD_USD || 50_000);
    this.replicationThresholdUsd = options.replicationThresholdUsd
      ?? Number(process.env.SOVEREIGN_REPLICATION_THRESHOLD_USD || 500_000);
    this.penningTrapMinIntegrity = options.penningTrapMinIntegrity
      ?? Number(process.env.HELIX_PENNING_TRAP_MIN || 0.72);
    this.nexusReservePool = options.nexusReservePool || 'nexus_primary';

    this.state = LOOP_STATES.IDLE;
    this.logs = [];
    this.tickCount = 0;
    this.chainBalances = Object.fromEntries(CHAINS.map((c) => [c, 0]));
    this.running = false;
    this._interval = null;
    this.credentialsOk = false;
    this.penningTrapIntegrity = Number(process.env.HELIX_PENNING_TRAP_INTEGRITY || 0.88);

    try {
      assertSovereignCredentials();
      this.credentialsOk = true;
    } catch {
      this.credentialsOk = false;
      this.state = LOOP_STATES.ERROR;
    }
  }

  _pushLog(entry) {
    this.logs.push(entry);
    if (this.logs.length > 200) {
      this.logs = this.logs.slice(-200);
    }
  }

  /**
   * Ingest multi-chain treasury telemetry (simulated or live feed).
   */
  async ingestTreasuryTelemetry(feed = {}) {
    for (const chain of CHAINS) {
      const val = feed[chain] ?? feed[`${chain}_usd`] ?? feed.balances?.[chain];
      if (val != null) {
        this.chainBalances[chain] = Number(val) || 0;
      }
    }
    if (!Object.values(this.chainBalances).some((v) => v > 0)) {
      const consolidated = Number(feed.consolidated_usd ?? feed.vault_usd ?? 0);
      const perChain = consolidated / CHAINS.length;
      for (const chain of CHAINS) {
        this.chainBalances[chain] = perChain;
      }
    }
    return { ...this.chainBalances };
  }

  /**
   * Loop 1 — Economic: treasury reallocation across chains.
   */
  evaluateTreasuryHealth() {
    const deficits = [];
    const transfers = [];

    for (const [chain, balance] of Object.entries(this.chainBalances)) {
      if (balance < this.treasuryThresholdUsd) {
        const deficit = this.treasuryThresholdUsd - balance;
        deficits.push({ chain, balance, deficit });
        if (chain !== 'nexus') {
          transfers.push({
            from: this.nexusReservePool,
            to: chain,
            amount_usd: deficit,
            simulated: true,
          });
        }
      }
    }

    const healthy = deficits.length === 0;
    return { healthy, deficits, transfers, threshold_usd: this.treasuryThresholdUsd };
  }

  /**
   * Loop 2 — Replication: provision workers when surplus exceeds threshold.
   */
  checkReplicationStatus() {
    const consolidated = Object.values(this.chainBalances).reduce((a, b) => a + b, 0);
    const surplus = consolidated - this.replicationThresholdUsd;

    if (surplus <= 0) {
      return {
        shouldReplicate: false,
        consolidated_usd: consolidated,
        surplus_usd: 0,
        replicationThresholdUsd: this.replicationThresholdUsd,
      };
    }

    const replicaId = `swarm-replica-${Date.now()}`;
    return {
      shouldReplicate: true,
      consolidated_usd: consolidated,
      surplus_usd: surplus,
      replicationThresholdUsd: this.replicationThresholdUsd,
      deployment: {
        replica_id: replicaId,
        target_env: process.env.SOVEREIGN_REPLICA_TARGET || 'akash',
        coordinates: {
          provider: 'akash',
          region: process.env.AKASH_REGION || 'us-west',
          gpu: 'rtx5090',
        },
        status: 'provisioning_simulated',
      },
    };
  }

  /**
   * Loop 3 — Adaptation: self-heal on anomalies / Penning trap integrity drop.
   */
  triggerPatchCycle(anomaly = {}) {
    const penningIntegrity = Number(
      anomaly.penning_trap_integrity
      ?? anomaly.penningTrapIntegrity
      ?? 0.85,
    );
    const connectivityOk = anomaly.connectivity_ok !== false;

    const needsHeal = !connectivityOk
      || penningIntegrity < this.penningTrapMinIntegrity;

    if (!needsHeal) {
      return { patched: false, penningIntegrity, connectivityOk };
    }

    const checkpoint = `stable-${Date.now() - 86_400_000}`;
    return {
      patched: true,
      penningIntegrity,
      connectivityOk,
      actions: [
        'isolate_failing_channel',
        `rollback_checkpoint:${checkpoint}`,
        'reinitialize_telemetry_stream',
      ],
      checkpoint,
      global_runtime_interrupted: false,
    };
  }

  /**
   * Single sovereign tick — runs all three loops in order.
   */
  async tick(telemetryFeed = {}, anomalyFeed = {}) {
    if (!this.credentialsOk) {
      this._pushLog(logEntry('error', 'Tick skipped — credentials not configured'));
      return this.snapshot();
    }

    this.tickCount += 1;
    this.state = LOOP_STATES.IDLE;
    await this.ingestTreasuryTelemetry(telemetryFeed);

    const economic = this.evaluateTreasuryHealth();
    if (!economic.healthy && economic.transfers.length) {
      this.state = LOOP_STATES.REBALANCING;
      this._pushLog(logEntry('economic', 'Treasury rebalance triggered', {
        transfers: economic.transfers,
        deficits: economic.deficits,
      }));
      for (const t of economic.transfers) {
        this.chainBalances[t.to] = (this.chainBalances[t.to] || 0) + t.amount_usd;
        if (t.from === this.nexusReservePool) {
          this.chainBalances.nexus = Math.max(
            0,
            (this.chainBalances.nexus || 0) - t.amount_usd,
          );
        }
      }
    }

    const replication = this.checkReplicationStatus();
    if (replication.shouldReplicate) {
      this.state = LOOP_STATES.REPLICATING;
      this._pushLog(logEntry('replication', 'Replica deployment initiated', {
        deployment: replication.deployment,
        surplus_usd: replication.surplus_usd,
      }));
    }

    this.penningTrapIntegrity = Number(
      anomalyFeed.penning_trap_integrity
      ?? anomalyFeed.penningTrapIntegrity
      ?? this.penningTrapIntegrity,
    );

    const heal = this.triggerPatchCycle(anomalyFeed);
    if (heal.patched) {
      this.state = LOOP_STATES.HEALING;
      this._pushLog(logEntry('adaptation', 'Self-heal patch cycle complete', {
        actions: heal.actions,
        checkpoint: heal.checkpoint,
      }));
    }

    if (
      this.state === LOOP_STATES.IDLE
      && this.tickCount % 10 === 0
    ) {
      this._pushLog(logEntry('heartbeat', 'Sovereign loops nominal', {
        tick: this.tickCount,
        chains: { ...this.chainBalances },
      }));
    }

    await this.persist();
    return this.snapshot();
  }

  consolidatedTreasuryUsd() {
    return Object.values(this.chainBalances).reduce((a, b) => a + b, 0);
  }

  replicationSurplusUsd() {
    return Math.max(0, this.consolidatedTreasuryUsd() - this.replicationThresholdUsd);
  }

  /**
   * Manual override — force economic rebalance from Nexus reserve.
   */
  async forceRebalance() {
    if (!this.credentialsOk) {
      this._pushLog(logEntry('error', 'Force rebalance skipped — credentials not configured'));
      return this.snapshot();
    }
    for (const chain of CHAINS) {
      if (chain !== 'nexus') {
        this.chainBalances[chain] = this.treasuryThresholdUsd * 0.4;
      }
    }
    this.state = LOOP_STATES.REBALANCING;
    const economic = this.evaluateTreasuryHealth();
    for (const t of economic.transfers) {
      this.chainBalances[t.to] = (this.chainBalances[t.to] || 0) + t.amount_usd;
      if (t.from === this.nexusReservePool) {
        this.chainBalances.nexus = Math.max(0, (this.chainBalances.nexus || 0) - t.amount_usd);
      }
    }
    this._pushLog(logEntry('override', 'Manual force rebalance executed', {
      transfers: economic.transfers,
      type: 'warning',
    }));
    await this.persist();
    return this.snapshot();
  }

  /**
   * Manual override — force replica provisioning.
   */
  async forceReplicate() {
    if (!this.credentialsOk) {
      this._pushLog(logEntry('error', 'Force replicate skipped — credentials not configured'));
      return this.snapshot();
    }
    const boost = this.replicationThresholdUsd * 1.25;
    const perChain = boost / CHAINS.length;
    for (const chain of CHAINS) {
      this.chainBalances[chain] = Math.max(this.chainBalances[chain] || 0, perChain);
    }
    this.state = LOOP_STATES.REPLICATING;
    const replication = this.checkReplicationStatus();
    this._pushLog(logEntry('override', 'Manual force replicate executed', {
      deployment: replication.deployment,
      surplus_usd: replication.surplus_usd,
      type: 'system',
    }));
    await this.persist();
    return this.snapshot();
  }

  /**
   * Manual override — trigger self-heal patch cycle.
   */
  async forcePatch() {
    if (!this.credentialsOk) {
      this._pushLog(logEntry('error', 'Force patch skipped — credentials not configured'));
      return this.snapshot();
    }
    this.penningTrapIntegrity = this.penningTrapMinIntegrity * 0.5;
    this.state = LOOP_STATES.HEALING;
    const heal = this.triggerPatchCycle({ penning_trap_integrity: this.penningTrapIntegrity });
    this.penningTrapIntegrity = 0.92;
    this._pushLog(logEntry('override', 'Manual patch cycle triggered', {
      actions: heal.actions,
      checkpoint: heal.checkpoint,
      type: 'critical',
    }));
    await this.persist();
    return this.snapshot();
  }

  /**
   * Manual override — pause daemon and reset loop state to nominal idle.
   */
  async pauseAndReset() {
    this.stopDaemon();
    this.state = LOOP_STATES.IDLE;
    this.tickCount = 0;
    this._pushLog(logEntry('override', 'Loops paused and state reset', { type: 'system' }));
    await this.persist();
    return this.snapshot();
  }

  snapshot() {
    const consolidated = this.consolidatedTreasuryUsd();
    const surplus = this.replicationSurplusUsd();
    return {
      version: '1.0.0-Beta',
      state: this.state,
      tickCount: this.tickCount,
      credentialsOk: this.credentialsOk,
      running: this.running,
      chainBalances: { ...this.chainBalances },
      logs: [...this.logs],
      chains: CHAINS,
      metrics: {
        consolidated_treasury_usd: consolidated,
        replication_surplus_usd: surplus,
        replication_progress_pct: Math.min(
          100,
          Math.round((consolidated / Math.max(this.replicationThresholdUsd, 1)) * 100),
        ),
        penning_trap_integrity: this.penningTrapIntegrity,
      },
      thresholds: {
        treasury_usd: this.treasuryThresholdUsd,
        replication_usd: this.replicationThresholdUsd,
        penning_trap_min: this.penningTrapMinIntegrity,
      },
      timestamp: nowIso(),
    };
  }

  async persist() {
    await fs.mkdir(path.dirname(STATE_PATH), { recursive: true });
    await fs.writeFile(STATE_PATH, `${JSON.stringify(this.snapshot(), null, 2)}\n`, 'utf8');
  }

  async load() {
    try {
      const raw = await fs.readFile(STATE_PATH, 'utf8');
      const saved = JSON.parse(raw);
      this.logs = saved.logs || [];
      this.tickCount = saved.tickCount || 0;
      this.chainBalances = saved.chainBalances || this.chainBalances;
      this.state = saved.state || LOOP_STATES.IDLE;
    } catch {
      // cold start
    }
  }

  startDaemon(intervalMs = null) {
    const ms = intervalMs ?? Number(process.env.SOVEREIGN_LOOP_INTERVAL_MS || 30_000);
    if (this._interval) return this.snapshot();

    this.running = true;
    this._interval = setInterval(() => {
      this.tick().catch((err) => {
        this._pushLog(logEntry('error', err.message));
      });
    }, ms);

    this._pushLog(logEntry('boot', 'Sovereign Loop daemon started', { interval_ms: ms }));
    return this.snapshot();
  }

  stopDaemon() {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
    this.running = false;
    this._pushLog(logEntry('shutdown', 'Sovereign Loop daemon stopped'));
    return this.snapshot();
  }
}

let singleton = null;

export function getSovereignLoopManager() {
  if (!singleton) singleton = new SovereignLoopManager();
  return singleton;
}

export async function initSovereignLoopEngine() {
  const mgr = getSovereignLoopManager();
  await mgr.load();
  if (process.env.SOVEREIGN_LOOP_DAEMON !== '0' && mgr.credentialsOk) {
    mgr.startDaemon();
  }
  return mgr;
}
