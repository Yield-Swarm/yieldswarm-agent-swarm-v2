/**
 * Great Delta integration — unified overview, telemetry ingest, optional EVM reads.
 */

import config from '../config.js';
import * as emission from './emissionRouter.js';
import * as treasury from './treasury.js';
import {
  BUCKET_LABELS,
  GREAT_DELTA_SPLIT_BPS,
  LEGACY_SPLIT_PCT,
  splitAmount,
  validateSplitBps,
  withLegacyAliases,
} from '../lib/great-delta-split.js';
import { rpc } from '../lib/http.js';

const PREVIEW_SPLIT_SELECTOR = '0x13a6c05f';
const TREASURIES_SELECTOR = '0x797c82a7';
const MAX_EVENTS = 200;

/** @type {Array<Record<string, unknown>>} */
const telemetryEvents = [];

function encodeUint256(value) {
  return BigInt(value).toString(16).padStart(64, '0');
}

function decodeUint256(hex, offset = 0) {
  const slice = hex.slice(2 + offset * 64, 2 + (offset + 1) * 64);
  return BigInt(`0x${slice || '0'}`);
}

function decodeAddress(hex, offset) {
  const slice = hex.slice(2 + offset * 64 + 24, 2 + (offset + 1) * 64);
  return `0x${slice.toLowerCase()}`;
}

async function ethCall(to, data) {
  const rpcUrl = config.evm.rpcUrl;
  if (!rpcUrl || !to) {
    return { live: false, error: 'EVM RPC or router address not configured' };
  }
  try {
    const result = await rpc(rpcUrl, 'eth_call', [{ to, data }, 'latest']);
    return { live: true, result };
  } catch (err) {
    return { live: false, error: err.message || 'eth_call failed' };
  }
}

export async function getEvmRouterState() {
  const address = config.evm.emissionRouter;
  if (!address || !config.evm.enabled) {
    return {
      live: false,
      source: 'disabled',
      address: address || null,
      error: 'EMISSION_ROUTER_EVM_ADDRESS unset or EVM_ENABLED=0',
    };
  }

  const previewCall = await ethCall(
    address,
    `${PREVIEW_SPLIT_SELECTOR}${encodeUint256(1_000_000)}`,
  );
  const treasuries = [];
  for (let i = 0; i < 4; i += 1) {
    const call = await ethCall(address, `${TREASURIES_SELECTOR}${encodeUint256(i)}`);
    if (call.live && call.result) {
      treasuries.push(decodeAddress(call.result, 0));
    }
  }

  let onChainSplit = null;
  if (previewCall.live && previewCall.result) {
    const hex = previewCall.result;
    onChainSplit = withLegacyAliases({
      coreTreasury: Number(decodeUint256(hex, 0)),
      growthTreasury: Number(decodeUint256(hex, 1)),
      insuranceTreasury: Number(decodeUint256(hex, 2)),
      opsTreasury: Number(decodeUint256(hex, 3)),
    });
  }

  return {
    live: previewCall.live,
    source: previewCall.live ? 'evm-rpc' : 'fallback',
    address,
    rpcUrl: config.evm.rpcUrl ? '(configured)' : null,
    treasuries: treasuries.length === 4 ? treasuries : null,
    previewSplit1M: onChainSplit,
    error: previewCall.live ? null : previewCall.error,
  };
}

export async function getGreatDeltaOverview() {
  validateSplitBps(config.treasurySplitsBps);

  const [emissions, treasurySplits, evm] = await Promise.all([
    emission.getEmissions(),
    treasury.getTreasurySplits(),
    getEvmRouterState(),
  ]);

  const emissionAmount = emissions.emissionPerEpoch ?? 0;
  const treasuryAmount = treasurySplits.totalSol ?? 0;

  return {
    policy: '50/30/15/5',
    splitBps: config.treasurySplitsBps,
    buckets: Object.entries(GREAT_DELTA_SPLIT_BPS).map(([bucket, bps]) => ({
      bucket,
      label: BUCKET_LABELS[bucket],
      bps,
      pct: bps / 100,
    })),
    legacySplitPct: LEGACY_SPLIT_PCT,
    emission: {
      ...emissions,
      split: splitAmount(emissionAmount),
      splitWithAliases: withLegacyAliases(
        Object.fromEntries(splitAmount(emissionAmount).map((r) => [r.bucket, r.amount])),
      ),
    },
    treasury: {
      ...treasurySplits,
      split: treasurySplits.splits,
      splitWithAliases: withLegacyAliases(
        Object.fromEntries((treasurySplits.splits || []).map((r) => [r.bucket, r.sol])),
      ),
    },
    evm,
    telemetry: {
      eventCount: telemetryEvents.length,
      recent: telemetryEvents.slice(-10),
    },
    generatedAt: new Date().toISOString(),
  };
}

export function ingestTelemetryEvent(event) {
  const record = {
    ...event,
    receivedAt: new Date().toISOString(),
  };
  telemetryEvents.push(record);
  if (telemetryEvents.length > MAX_EVENTS) {
    telemetryEvents.splice(0, telemetryEvents.length - MAX_EVENTS);
  }
  return record;
}

export function getTelemetryEvents(limit = 50) {
  return telemetryEvents.slice(-limit);
}

export default {
  getGreatDeltaOverview,
  getEvmRouterState,
  ingestTelemetryEvent,
  getTelemetryEvents,
};
