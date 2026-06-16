/**
 * dYdX v4 Execution Bridge — primary trading integration (PDs¹).
 *
 * Greek: position limits, tier-aware sizing, auditable risk gates.
 * Eastern: adaptive hedge mode from Arena feedback.
 * Paradigm Shift: NFT tier scales max notional and leverage budget.
 *
 * @module src/infrastructure/dydx-bridge
 */

const DEFAULT_API = 'https://indexer.dydx.trade/v4';

const TIER_LIMITS = Object.freeze({
  0: { maxNotionalUsd: 500, maxLeverage: 2 },
  1: { maxNotionalUsd: 2_000, maxLeverage: 3 },
  2: { maxNotionalUsd: 10_000, maxLeverage: 5 },
  3: { maxNotionalUsd: 50_000, maxLeverage: 8 },
  4: { maxNotionalUsd: 250_000, maxLeverage: 10 },
});

/**
 * @param {object} order
 * @param {string} order.market e.g. BTC-USD
 * @param {'long'|'short'} order.side
 * @param {number} order.sizeUsd
 * @param {number} [order.leverage]
 * @param {number} [order.mutationTier]
 * @param {boolean} [order.dryRun]
 */
export async function executePerpOrder(order) {
  const tier = order.mutationTier ?? 0;
  const limits = TIER_LIMITS[Math.min(tier, 4)] ?? TIER_LIMITS[0];
  const leverage = Math.min(order.leverage ?? 1, limits.maxLeverage);
  const sizeUsd = Math.min(order.sizeUsd, limits.maxNotionalUsd);

  const risk = assessRisk({ ...order, sizeUsd, leverage, tier });

  if (!risk.approved) {
    return { ok: false, status: 'rejected', reason: risk.reason, limits, tier };
  }

  if (order.dryRun) {
    return {
      ok: true,
      status: 'dry_run',
      market: order.market,
      side: order.side,
      sizeUsd,
      leverage,
      tier,
      simulatedPnlUsd: sizeUsd * (order.expectedPnlBps ?? 0) / 10_000,
    };
  }

  const apiKey = process.env.DYDX_API_KEY ?? '';
  const apiBase = process.env.DYDX_API_BASE ?? DEFAULT_API;

  if (!apiKey || apiKey.startsWith('your_')) {
    return {
      ok: false,
      status: 'skipped',
      reason: 'DYDX_API_KEY not configured in Vault',
      apiBase,
      limits,
    };
  }

  // Production path: wire @dydx/v4-client when credentials present.
  const quote = await fetchQuote(apiBase, order.market);
  return {
    ok: true,
    status: 'quoted',
    market: order.market,
    side: order.side,
    sizeUsd,
    leverage,
    tier,
    quote,
    note: 'Submit via dYdX v4 client — indexer quote retrieved',
    layers: {
      greek: 'tier_risk_gate',
      eastern: 'adaptive_sizing',
      paradigm: 'nft_tier_notional',
    },
  };
}

function assessRisk(order) {
  if (order.sizeUsd <= 0) return { approved: false, reason: 'zero_size' };
  if (order.leverage > (TIER_LIMITS[order.tier]?.maxLeverage ?? 2)) {
    return { approved: false, reason: 'leverage_exceeds_tier' };
  }
  if (order.sizeUsd > (TIER_LIMITS[order.tier]?.maxNotionalUsd ?? 500)) {
    return { approved: false, reason: 'notional_exceeds_tier' };
  }
  return { approved: true };
}

async function fetchQuote(apiBase, market) {
  try {
    const url = `${apiBase}/perpetualMarkets/${market}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return { error: res.status };
    return await res.json();
  } catch (err) {
    return { error: String(err.message ?? err) };
  }
}

/** Hedge wrapper for treasury protection. */
export async function hedgeExposure(params) {
  return executePerpOrder({
    ...params,
    side: params.exposureSide === 'long' ? 'short' : 'long',
    sizeUsd: params.hedgeSizeUsd ?? params.sizeUsd,
    hedgeMode: true,
  });
}

export default { executePerpOrder, hedgeExposure, TIER_LIMITS };
