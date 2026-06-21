/**
 * Sovereign Loop Manager — autonomous economic, replication, and self-heal loops.
 * Helix Chain v5.0 Delta Variant integration surface.
 */

'use strict';

const LOOP_STATES = [
  'Nominal',
  'Rebalancing Funds',
  'Deploying Replica',
  'Executing Self-Heal Patch',
];

const MAX_LOGS = 120;

function timestamp() {
  return new Date().toISOString().replace('T', ' ').slice(0, 19);
}

function createLog(type, message) {
  return { type, message, timestamp: timestamp() };
}

class SovereignLoopManager {
  constructor() {
    this.currentState = 'Nominal';
    this.logs = [
      createLog('System', 'Sovereign daemon initialized — all loops armed'),
      createLog('System', 'Penning trap flux core linked to Helix Delta v5'),
    ];
    this.treasuries = { nexus: 0, helix: 0, shadow: 0 };
    this.totalTreasury = 0;
    this.penningTrapIntegrity = 99.99995;
    this.replicationSurplus = 0;
    this._tick = 0;
    this._forcedState = null;
    this._forcedStateUntil = 0;
  }

  _pushLog(type, message) {
    this.logs.unshift(createLog(type, message));
    if (this.logs.length > MAX_LOGS) {
      this.logs.length = MAX_LOGS;
    }
  }

  _resolveState() {
    if (this._forcedState && Date.now() < this._forcedStateUntil) {
      return this._forcedState;
    }
    this._forcedState = null;
    const phase = this._tick % 24;
    if (phase === 7 || phase === 8) return 'Rebalancing Funds';
    if (phase === 14 || phase === 15) return 'Deploying Replica';
    if (this.replicationSurplus < 42 || this.penningTrapIntegrity < 99.99) {
      return 'Executing Self-Heal Patch';
    }
    return 'Nominal';
  }

  /**
   * Ingest live sovereign + helix telemetry overlays.
   */
  ingestTelemetry(overlay = {}) {
    const sovereign = overlay.sovereign || {};
    const helix = overlay.helix || {};
    const live = sovereign.live_overlay || {};

    const nav = Number(sovereign.net_worth_usd ?? sovereign.vault_usd ?? 0);
    const treasuryUsd = Number(sovereign.treasury_usd ?? nav * 0.35);
    const helixShare = Number(helix.treasuryNavUsd ?? nav * 0.28);
    const shadowShare = Math.max(0, nav - treasuryUsd - helixShare) * 0.15;

    this.treasuries = {
      nexus: Math.round(treasuryUsd),
      helix: Math.round(helixShare),
      shadow: Math.round(shadowShare),
    };
    this.totalTreasury = Math.round(nav || treasuryUsd + helixShare + shadowShare);

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
    this.currentState = this._resolveState();

    if (this.currentState === 'Rebalancing Funds') {
      this._pushLog('System', 'Great Delta 50/30/15/5 rebalance cycle engaged');
    } else if (this.currentState === 'Deploying Replica') {
      this._pushLog('System', `Provisioning worker shard — surplus ${this.replicationSurplus.toFixed(1)}%`);
    } else if (this.currentState === 'Executing Self-Heal Patch') {
      this._pushLog('Critical', 'Self-heal patch dispatched to degraded Akash leases');
    } else if (this._tick % 12 === 0) {
      this._pushLog('System', `Treasury NAV $${this.totalTreasury.toLocaleString()} — loops nominal`);
    }

    if (this.penningTrapIntegrity < 99.99) {
      this._pushLog('Warning', `Penning trap field ${this.penningTrapIntegrity.toFixed(4)}% — flux bleed detected`);
    }
  }

  forceRebalance() {
    this._forcedState = 'Rebalancing Funds';
    this._forcedStateUntil = Date.now() + 8000;
    this.currentState = this._forcedState;
    this._pushLog('System', 'Manual override: economic balancing forced');
    return this.snapshot();
  }

  forceReplicate() {
    this._forcedState = 'Deploying Replica';
    this._forcedStateUntil = Date.now() + 8000;
    this.currentState = this._forcedState;
    this.replicationSurplus = Math.min(100, this.replicationSurplus + 4.2);
    this._pushLog('System', 'Manual override: worker swarm provisioning initiated');
    return this.snapshot();
  }

  triggerPatch() {
    this._forcedState = 'Executing Self-Heal Patch';
    this._forcedStateUntil = Date.now() + 10000;
    this.currentState = this._forcedState;
    this.penningTrapIntegrity = Math.min(99.99999, this.penningTrapIntegrity + 0.002);
    this._pushLog('Critical', 'Manual self-heal cycle triggered — patching sovereign runtime');
    return this.snapshot();
  }

  snapshot() {
    return {
      currentState: this.currentState,
      logs: [...this.logs],
      treasuries: { ...this.treasuries },
      totalTreasury: this.totalTreasury,
      penningTrapIntegrity: this.penningTrapIntegrity,
      replicationSurplus: this.replicationSurplus,
    };
  }
}

let manager = new SovereignLoopManager();

function getSovereignLoopManager() {
  return manager;
}

function resetSovereignLoopManager() {
  manager = new SovereignLoopManager();
  return manager;
}

module.exports = {
  SovereignLoopManager,
  getSovereignLoopManager,
  resetSovereignLoopManager,
  LOOP_STATES,
};
