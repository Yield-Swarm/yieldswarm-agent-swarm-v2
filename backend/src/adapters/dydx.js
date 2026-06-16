/**
 * dYdX adapter — wraps DydxExecutionBridge for Arena API routes.
 */

import config from '../config.js';
import { DydxExecutionBridge } from '../infrastructure/dydx-bridge.js';

let bridge;

function getBridge(subaccountId) {
  return new DydxExecutionBridge(
    config.dydx.indexerUrl,
    subaccountId || config.dydx.subaccountId,
  );
}

export async function getDydxHealth() {
  const b = getBridge();
  const ping = await b.ping();
  return {
    ...ping,
    subaccountConfigured: Boolean(config.dydx.subaccountId),
    source: ping.live ? 'dydx-indexer' : 'unavailable',
  };
}

export async function getMarketPrice(ticker) {
  const b = getBridge();
  try {
    return await b.getMarketPrice(ticker);
  } catch (err) {
    return {
      ticker,
      live: false,
      source: 'dydx-indexer',
      error: err.message,
    };
  }
}

export async function getActivePositions(subaccountId) {
  const b = getBridge(subaccountId);
  return b.fetchActivePositions();
}

export { DydxExecutionBridge };
