/**
 * Kairo marketplace fee model.
 *
 * Customer: flat 1% platform fee on ride fare.
 * Driver:    2× base pay multiplier + optional instant cashout fee.
 */

export const CUSTOMER_PLATFORM_FEE_RATE = 0.01; // 1%
export const DRIVER_PAY_MULTIPLIER = 2.0; // 2× base pay
export const INSTANT_CASHOUT_FEE_RATE = 0.015; // 1.5% for instant Wise/Square payout

export interface RideFareInput {
  /** Base fare before fees, in major currency units (e.g. dollars). */
  baseFare: string;
  currency?: string;
}

export interface RideFareBreakdown {
  currency: string;
  baseFare: string;
  customerPlatformFee: string;
  customerTotal: string;
  driverBasePay: string;
  driverBonusPay: string;
  driverGrossPay: string;
  platformRevenue: string;
  depinRewardEstimateUsd: string;
}

function parseAmount(value: string): number {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw new Error(`invalid amount: ${value}`);
  return n;
}

function fmt(amount: number, decimals = 2): string {
  return amount.toFixed(decimals);
}

export function calculateRideFare(input: RideFareInput): RideFareBreakdown {
  const currency = input.currency ?? "USD";
  const base = parseAmount(input.baseFare);

  const customerFee = base * CUSTOMER_PLATFORM_FEE_RATE;
  const customerTotal = base + customerFee;

  const driverBasePay = base * 0.7; // 70% of base to driver before multiplier
  const driverGrossPay = driverBasePay * DRIVER_PAY_MULTIPLIER;
  const driverBonusPay = driverGrossPay - driverBasePay;

  const platformRevenue = customerFee + (base - driverBasePay);
  const depinRewardEstimate = base * 0.02; // 2% DePIN/crypto reward pool estimate

  return {
    currency,
    baseFare: fmt(base),
    customerPlatformFee: fmt(customerFee),
    customerTotal: fmt(customerTotal),
    driverBasePay: fmt(driverBasePay),
    driverBonusPay: fmt(driverBonusPay),
    driverGrossPay: fmt(driverGrossPay),
    platformRevenue: fmt(platformRevenue),
    depinRewardEstimateUsd: fmt(depinRewardEstimate),
  };
}

export interface DriverEarningsInput {
  appRevenueUsd: string;
  depinRewardsUsd: string;
  cryptoRewardsUsd?: string;
  instantCashout?: boolean;
}

export interface DriverEarningsBreakdown {
  appRevenueUsd: string;
  depinRewardsUsd: string;
  cryptoRewardsUsd: string;
  grossTotalUsd: string;
  instantCashoutFeeUsd: string;
  netPayoutUsd: string;
}

export function calculateDriverEarnings(input: DriverEarningsInput): DriverEarningsBreakdown {
  const app = parseAmount(input.appRevenueUsd);
  const depin = parseAmount(input.depinRewardsUsd);
  const crypto = parseAmount(input.cryptoRewardsUsd ?? "0");
  const gross = app + depin + crypto;

  let cashoutFee = 0;
  if (input.instantCashout) {
    cashoutFee = gross * INSTANT_CASHOUT_FEE_RATE;
  }

  return {
    appRevenueUsd: fmt(app),
    depinRewardsUsd: fmt(depin),
    cryptoRewardsUsd: fmt(crypto),
    grossTotalUsd: fmt(gross),
    instantCashoutFeeUsd: fmt(cashoutFee),
    netPayoutUsd: fmt(gross - cashoutFee),
  };
}
