/** Circuit breaker + Gnosis Safe execution gating */

import type { CircuitBreakerResult, RoutePlan } from "./types.js";

const WHITELISTED_BRIDGES = new Set(["stargate", "cctp", "symbiosis", "debridge"]);
const WHITELISTED_SWAPS = new Set(["oneinch", "curve", "uniswap"]);

export interface SecurityConfig {
  feeThresholdPct: number;
  sessionKeyExpiryHours: number;
  sessionKeyMaxUsd: number;
  gnosisSafeAddress?: string;
  gnosisThreshold: number;
}

export const DEFAULT_SECURITY: SecurityConfig = {
  feeThresholdPct: Number(process.env.DEFI_ROUTER_FEE_THRESHOLD_PCT ?? 30),
  sessionKeyExpiryHours: 1,
  sessionKeyMaxUsd: 1000,
  gnosisSafeAddress: process.env.GNOSIS_SAFE_ADDRESS,
  gnosisThreshold: 2,
};

export function evaluateCircuitBreaker(
  route: RoutePlan,
  portfolioUsd: number,
  thresholdPct = DEFAULT_SECURITY.feeThresholdPct,
): CircuitBreakerResult {
  const triggered = route.feePct > thresholdPct;
  const minViable = 50;
  return {
    triggered,
    thresholdPct,
    actualFeePct: route.feePct,
    reason: triggered
      ? `Projected fees ${route.feePct.toFixed(1)}% exceed ${thresholdPct}% threshold on $${portfolioUsd.toFixed(2)} portfolio`
      : `Fees ${route.feePct.toFixed(1)}% within ${thresholdPct}% threshold`,
    recommendation: triggered
      ? `WAIT — accumulate to $${minViable}+ before executing (${route.strategyName})`
      : "PROCEED — route viable; confirm multi-sig approval",
  };
}

export function assertProviderWhitelist(providers: string[]): void {
  for (const p of providers) {
    if (!WHITELISTED_BRIDGES.has(p) && !WHITELISTED_SWAPS.has(p)) {
      throw new Error(`Provider not whitelisted: ${p}`);
    }
  }
}

/**
 * Gnosis Safe proposal stub — production wires @safe-global/protocol-kit.
 * Requires GNOSIS_SAFE_ADDRESS and offline signers.
 */
export async function proposeSafeBatch(
  route: RoutePlan,
  config: SecurityConfig = DEFAULT_SECURITY,
): Promise<{ status: string; safeAddress?: string; stepCount: number }> {
  assertProviderWhitelist(route.providersUsed);

  if (!config.gnosisSafeAddress) {
    return {
      status: "DRY_RUN",
      stepCount: route.steps.length,
      safeAddress: undefined,
    };
  }

  // ProtocolKit.create({ provider, signer, safeAddress })
  // const safeTx = await protocolKit.createTransaction({ transactions: [...] })
  return {
    status: "PROPOSED",
    safeAddress: config.gnosisSafeAddress,
    stepCount: route.steps.length,
  };
}

/**
 * Session key scope check (ERC-4337).
 */
export function validateSessionKeyScope(notionalUsd: number, config = DEFAULT_SECURITY): void {
  if (notionalUsd > config.sessionKeyMaxUsd) {
    throw new Error(
      `Notional $${notionalUsd} exceeds session key cap $${config.sessionKeyMaxUsd}`,
    );
  }
}
