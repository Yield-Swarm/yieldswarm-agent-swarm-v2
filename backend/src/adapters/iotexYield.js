/**
 * Helix Solenoid 2 — IoTeX / IOPAY cross-chain yield routing.
 *
 * receive_cross_chain_yield routes agent yields to IoTeX treasury or BTC bridge
 * per TREASURY_MANIFEST.json (overridable via env).
 */

import crypto from 'node:crypto';
import {
  IOTEX_YIELD_DESTINATIONS,
  loadTreasuryManifest,
  resolveYieldDestination,
  getIotexHubStatus,
} from '../lib/treasury-manifest.js';

/** @typedef {import('../lib/treasury-manifest.js').YieldDestination} YieldDestination */

/**
 * @typedef {object} CrossChainYieldRequest
 * @property {string} agentId
 * @property {string} amount — decimal string
 * @property {string} [currency] — default USDC
 * @property {YieldDestination} destination — iotex | btc_iopay | mining root keys
 * @property {string} [sourceChain]
 * @property {string} [txHash]
 * @property {Record<string, unknown>} [metadata]
 */

/** In-memory event log (swap for Postgres/Neon in production). */
const inflowEvents = [];

/**
 * Route cross-chain yield to a manifest destination.
 * @param {CrossChainYieldRequest} request
 */
export function receiveCrossChainYield(request) {
  if (!request?.agentId) {
    throw new Error('agentId is required');
  }
  if (!request?.amount || Number(request.amount) <= 0) {
    throw new Error('amount must be a positive decimal string');
  }
  if (!request?.destination) {
    throw new Error('destination is required');
  }

  const target = resolveYieldDestination(request.destination);
  const eventId = crypto.randomUUID();
  const receivedAt = new Date().toISOString();

  /** @type {object} */
  const event = {
    type: 'IotexYieldInflow',
    eventId,
    agentId: request.agentId,
    amount: String(request.amount),
    currency: request.currency || 'USDC',
    destination: request.destination,
    targetAddress: target.address,
    targetChain: target.chain,
    sourceChain: request.sourceChain || 'helix',
    txHash: request.txHash || null,
    metadata: request.metadata || {},
    receivedAt,
    status: 'routed',
    manifestVersion: loadTreasuryManifest().version,
  };

  inflowEvents.push(event);
  if (inflowEvents.length > 500) inflowEvents.shift();

  return {
    ok: true,
    routing: target,
    event,
  };
}

/**
 * Batch route to IoTeX hub (primary + optional BTC split).
 * @param {object} params
 * @param {string} params.agentId
 * @param {string} params.totalAmount
 * @param {number} [params.btcSplitBps] — portion to BTC bridge (default 0)
 */
export function receiveIotexHubYield(params) {
  const { agentId, totalAmount, btcSplitBps = 0 } = params;
  const total = Number(totalAmount);
  if (!agentId || !(total > 0)) {
    throw new Error('agentId and positive totalAmount required');
  }

  const btcBps = Math.min(10_000, Math.max(0, Number(btcSplitBps) || 0));
  const btcAmount = ((total * btcBps) / 10_000).toFixed(8);
  const iotexAmount = (total - Number(btcAmount)).toFixed(8);

  const results = [];

  if (Number(iotexAmount) > 0) {
    results.push(
      receiveCrossChainYield({
        agentId,
        amount: iotexAmount,
        destination: 'iotex',
        sourceChain: 'helix-iotex-hub',
        metadata: { leg: 'primary', btcSplitBps: btcBps },
      }),
    );
  }

  if (Number(btcAmount) > 0) {
    results.push(
      receiveCrossChainYield({
        agentId,
        amount: btcAmount,
        destination: 'btc_iopay',
        sourceChain: 'helix-iotex-hub',
        metadata: { leg: 'btc_bridge', btcSplitBps: btcBps },
      }),
    );
  }

  return {
    ok: true,
    agentId,
    totalAmount: String(totalAmount),
    btcSplitBps: btcBps,
    legs: results,
  };
}

export function listIotexInflowEvents({ limit = 50, agentId } = {}) {
  let events = [...inflowEvents].reverse();
  if (agentId) events = events.filter((e) => e.agentId === agentId);
  return events.slice(0, limit);
}

/** Clear in-memory events (tests). */
export function clearIotexInflowEvents() {
  inflowEvents.length = 0;
}

/** Map public API destination names to manifest keys. */
export function normalizeYieldDestination(destination) {
  const aliases = {
    iotex_treasury: 'iotex',
    btc_via_iopay: 'btc_iopay',
  };
  return aliases[destination] || destination;
}

export function getHelixIotexRoutingStatus() {
  return {
    service: 'helix-solenoid-2-iotex',
    supportedDestinations: [...IOTEX_YIELD_DESTINATIONS, ...Object.keys(loadTreasuryManifest().mining_roots || {})],
    iotexHub: getIotexHubStatus(),
    recentInflowCount: inflowEvents.length,
  };
}

export default {
  receiveCrossChainYield,
  receiveIotexHubYield,
  listIotexInflowEvents,
  clearIotexInflowEvents,
  normalizeYieldDestination,
  getHelixIotexRoutingStatus,
};
