/**
 * Driver payout engine — 2× base pay + optional instant cashout.
 */

import { normalizeAmount, addAmounts, subAmounts } from "@/lib/money";
import { serverEnv } from "@/lib/config/env";

export interface DriverPayoutBreakdown {
  baseAmount: string;
  multiplier: number;
  grossPayout: string;
  instantCashoutFee: string;
  netPayout: string;
  appRevenue: string;
  depinRewards: string;
}

export function driverPayMultiplier(): number {
  return serverEnv.payments.driverPayMultiplier();
}

export function computeDriverPayout(input: {
  baseAmount: string;
  depinRewards?: string;
  instantCashout?: boolean;
}): DriverPayoutBreakdown {
  const base = normalizeAmount(input.baseAmount);
  const multiplier = driverPayMultiplier();
  const grossPayout = normalizeAmount((parseFloat(base) * multiplier).toFixed(8));
  const depin = normalizeAmount(input.depinRewards ?? "0");
  const instantRate = input.instantCashout
    ? serverEnv.payments.instantCashoutFeePercent()
    : 0;
  const instantCashoutFee = instantRate
    ? normalizeAmount((parseFloat(grossPayout) * instantRate).toFixed(8))
    : "0";
  const netPayout = subAmounts(addAmounts(grossPayout, depin), instantCashoutFee);
  return {
    baseAmount: base,
    multiplier,
    grossPayout,
    instantCashoutFee,
    netPayout,
    appRevenue: base,
    depinRewards: depin,
  };
}
