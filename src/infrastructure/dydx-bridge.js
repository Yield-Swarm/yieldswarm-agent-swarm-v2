/**
 * Paradigm Shift ($PDs^1$) — dYdX v4 perpetual indexer bridge with NFT-tier risk gates.
 */

const DEFAULT_INDEXER = "https://indexer.dydx.trade/v4";

/** Risk limits per agent NFT tier (1 = most restrictive, 5 = institutional). */
export const TIER_LIMITS = {
  1: { maxNotionalUsd: 500, maxLeverage: 2, dailyOrderCap: 10 },
  2: { maxNotionalUsd: 2_500, maxLeverage: 3, dailyOrderCap: 25 },
  3: { maxNotionalUsd: 10_000, maxLeverage: 5, dailyOrderCap: 50 },
  4: { maxNotionalUsd: 50_000, maxLeverage: 8, dailyOrderCap: 100 },
  5: { maxNotionalUsd: 250_000, maxLeverage: 10, dailyOrderCap: 500 },
};

/**
 * @param {number} tier
 * @returns {{ maxNotionalUsd: number, maxLeverage: number, dailyOrderCap: number }}
 */
export function limitsForTier(tier) {
  const t = Math.min(5, Math.max(1, Number(tier) || 1));
  return TIER_LIMITS[/** @type {keyof typeof TIER_LIMITS} */ (t)];
}

/**
 * @param {object} order
 * @param {number} order.agentTier
 * @param {number} order.notionalUsd
 * @param {number} [order.leverage]
 * @param {number} [order.dailyOrdersSoFar]
 */
export function validateOrderRisk(order) {
  const limits = limitsForTier(order.agentTier);
  const errors = [];

  if (order.notionalUsd > limits.maxNotionalUsd) {
    errors.push(`notional $${order.notionalUsd} exceeds tier-${order.agentTier} max $${limits.maxNotionalUsd}`);
  }
  const lev = order.leverage ?? 1;
  if (lev > limits.maxLeverage) {
    errors.push(`leverage ${lev}x exceeds tier-${order.agentTier} max ${limits.maxLeverage}x`);
  }
  const daily = order.dailyOrdersSoFar ?? 0;
  if (daily >= limits.dailyOrderCap) {
    errors.push(`daily order cap ${limits.dailyOrderCap} reached for tier-${order.agentTier}`);
  }

  if (errors.length) {
    const err = new Error(errors.join("; "));
    /** @type {Error & { code: string, errors: string[] }} */ (err).code = "RISK_GATE_REJECTED";
    /** @type {Error & { code: string, errors: string[] }} */ (err).errors = errors;
    throw err;
  }

  return { approved: true, limits };
}

export class DydxBridge {
  /**
   * @param {object} [opts]
   * @param {string} [opts.indexerBase]
   * @param {typeof fetch} [opts.fetchImpl]
   */
  constructor(opts = {}) {
    this.indexerBase = (opts.indexerBase || process.env.DYDX_INDEXER_URL || DEFAULT_INDEXER).replace(
      /\/$/,
      "",
    );
    this.fetchImpl = opts.fetchImpl || fetch;
    /** @type {Map<string, number>} */
    this.dailyOrderCounts = new Map();
  }

  /**
   * @param {string} agentId
   */
  _dailyKey(agentId) {
    const day = new Date().toISOString().slice(0, 10);
    return `${agentId}:${day}`;
  }

  /**
   * Fetch perpetual markets from dYdX v4 indexer.
   */
  async listMarkets() {
    const res = await this.fetchImpl(`${this.indexerBase}/perpetualMarkets`, {
      headers: { Accept: "application/json" },
    });
    if (!res.ok) {
      throw new Error(`dYdX indexer markets failed: HTTP ${res.status}`);
    }
    return res.json();
  }

  /**
   * Submit an order intent through risk gates (actual chain submission is out of band).
   * @param {object} params
   * @param {string} params.agentId
   * @param {number} params.agentTier NFT tier from YieldSwarmNFT
   * @param {string} params.market e.g. BTC-USD
   * @param {'BUY'|'SELL'} params.side
   * @param {number} params.size base size
   * @param {number} params.price
   * @param {number} [params.leverage]
   */
  async submitOrder(params) {
    const { agentId, agentTier, market, side, size, price, leverage = 1 } = params;
    const notionalUsd = size * price;
    const dailyKey = this._dailyKey(agentId);
    const dailyOrdersSoFar = this.dailyOrderCounts.get(dailyKey) ?? 0;

    validateOrderRisk({ agentTier, notionalUsd, leverage, dailyOrdersSoFar });

    const payload = {
      agentId,
      agentTier,
      market,
      side,
      size,
      price,
      leverage,
      notionalUsd,
      submittedAt: new Date().toISOString(),
      status: "risk_approved",
    };

    // Indexer placement is simulated here; production wires dYdX client keys via Vault.
    const res = await this.fetchImpl(`${this.indexerBase}/orders`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(payload),
    }).catch(() => null);

    this.dailyOrderCounts.set(dailyKey, dailyOrdersSoFar + 1);

    return {
      ...payload,
      indexerAccepted: res?.ok ?? false,
      indexerStatus: res?.status ?? 0,
      clientOrderId: `ys-${agentId}-${Date.now()}`,
    };
  }
}

export const dydxBridge = new DydxBridge();

export default dydxBridge;
