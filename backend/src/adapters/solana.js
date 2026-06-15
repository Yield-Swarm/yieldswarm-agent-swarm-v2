/**
 * Solana RPC adapter. Wraps the handful of JSON-RPC calls the on-chain
 * telemetry adapters need (balances, token supply, largest holders).
 *
 * Each method returns a normalized object and never throws to the caller for
 * "soft" failures — instead it returns `{ live: false, error }` so downstream
 * adapters can fall back gracefully while still reporting connection health.
 */

import config from '../config.js';
import { rpc, UpstreamError } from '../lib/http.js';

const LAMPORTS_PER_SOL = 1_000_000_000;

function isLikelyAddress(value) {
  // base58, 32-44 chars — good enough to skip obviously-empty/placeholder input.
  return typeof value === 'string' && /^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(value);
}

export async function getSolBalance(address) {
  if (!isLikelyAddress(address)) {
    return { live: false, sol: 0, lamports: 0, error: 'no address configured' };
  }
  try {
    const result = await rpc(config.solana.rpcUrl, 'getBalance', [address]);
    const lamports = result?.value ?? 0;
    return { live: true, lamports, sol: lamports / LAMPORTS_PER_SOL };
  } catch (err) {
    return { live: false, sol: 0, lamports: 0, error: err.message };
  }
}

export async function getTokenSupply(mint) {
  if (!isLikelyAddress(mint)) {
    return { live: false, error: 'no mint configured' };
  }
  try {
    const result = await rpc(config.solana.rpcUrl, 'getTokenSupply', [mint]);
    const v = result?.value || {};
    return {
      live: true,
      amount: Number(v.amount ?? 0),
      decimals: v.decimals ?? 0,
      uiAmount: v.uiAmount ?? Number(v.uiAmountString ?? 0),
    };
  } catch (err) {
    return { live: false, error: err.message };
  }
}

export async function getTokenLargestAccounts(mint) {
  if (!isLikelyAddress(mint)) {
    return { live: false, accounts: [], error: 'no mint configured' };
  }
  try {
    const result = await rpc(config.solana.rpcUrl, 'getTokenLargestAccounts', [mint]);
    const accounts = (result?.value || []).map((a) => ({
      address: a.address,
      amount: Number(a.amount ?? 0),
      uiAmount: a.uiAmount ?? Number(a.uiAmountString ?? 0),
    }));
    return { live: true, accounts };
  } catch (err) {
    return { live: false, accounts: [], error: err.message };
  }
}

/** Lightweight connectivity probe used by /api/health. */
export async function ping() {
  try {
    const result = await rpc(config.solana.rpcUrl, 'getHealth', [], { timeoutMs: 3000 });
    return { live: true, status: result ?? 'ok' };
  } catch (err) {
    const status = err instanceof UpstreamError ? err.status : undefined;
    return { live: false, error: err.message, status };
  }
}

export { isLikelyAddress, LAMPORTS_PER_SOL };
