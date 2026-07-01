/** YieldSwarm DeFiRouter — shared types */

export type Chain = "ethereum" | "arbitrum" | "avalanche" | "curve";

export interface AssetPosition {
  symbol: string;
  amountUsd: number;
  chain: Chain;
}

export interface Portfolio {
  positions: AssetPosition[];
}

export interface FeeLine {
  label: string;
  costUsd: number;
}

export interface RouteStep {
  action: string;
  provider: string;
  fromChain: string;
  toChain: string;
  inputUsd: number;
  outputUsd: number;
  feeUsd: number;
  gasUsd: number;
  notes?: string;
}

export interface RoutePlan {
  strategyId: string;
  strategyName: string;
  steps: RouteStep[];
  totalFeesUsd: number;
  netOutputUsd: number;
  feePct: number;
  retentionPct: number;
  feeBreakdown: FeeLine[];
  providersUsed: string[];
}

export interface CircuitBreakerResult {
  triggered: boolean;
  thresholdPct: number;
  actualFeePct: number;
  reason: string;
  recommendation: string;
}

export interface SimulationReport {
  portfolioUsd: number;
  bestRoute: RoutePlan;
  allRoutes: RoutePlan[];
  circuitBreaker: CircuitBreakerResult;
  execute: boolean;
}

export const DEFAULT_PORTFOLIO: Portfolio = {
  positions: [
    { symbol: "ETH", amountUsd: 16.0, chain: "ethereum" },
    { symbol: "CURVE_LP", amountUsd: 14.0, chain: "curve" },
    { symbol: "AVAX", amountUsd: 2.5, chain: "avalanche" },
  ],
};

export function portfolioTotalUsd(p: Portfolio): number {
  return Math.round(p.positions.reduce((s, x) => s + x.amountUsd, 0) * 100) / 100;
}
