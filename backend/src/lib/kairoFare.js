/**
 * Kairo fare calculations — 1% customer fee, 2× driver pay, DePIN estimate.
 * Mirrors src/lib/kairo/fees.ts for Express integration backend.
 */

export const KAIRO_CUSTOMER_FEE_PCT = 0.01;
export const KAIRO_DRIVER_MULTIPLIER = 2.0;
export const KAIRO_DEPIN_REWARD_RATE = Number(process.env.KAIRO_DEPIN_REWARD_RATE || 0.02);

/**
 * @param {{ distanceKm: number, durationMin: number, baseRatePerKm?: number, baseRatePerMin?: number, flatFee?: number }} input
 */
export function calculateKairoFare(input) {
  const km = Number(input.distanceKm) || 0;
  const min = Number(input.durationMin) || 0;
  const rateKm = input.baseRatePerKm ?? 1.5;
  const rateMin = input.baseRatePerMin ?? 0.25;
  const flat = input.flatFee ?? 2.5;

  const base = km * rateKm + min * rateMin + flat;
  const customerFee = base * KAIRO_CUSTOMER_FEE_PCT;
  const customerTotal = base + customerFee;
  const driverAppPay = base * KAIRO_DRIVER_MULTIPLIER;
  const depinScore = km * 0.01 + min * 0.005;
  const depinReward = depinScore * KAIRO_DEPIN_REWARD_RATE;

  const fmt = (n) => n.toFixed(2);
  const fmt4 = (n) => n.toFixed(4);

  return {
    baseFareUsd: fmt(base),
    customerFeeUsd: fmt(customerFee),
    customerTotalUsd: fmt(customerTotal),
    driverAppPayUsd: fmt(driverAppPay),
    depinRewardEstimateUsd: fmt4(depinReward),
    cryptoRewardEstimateUsd: '0.0000',
    driverTotalUsd: fmt(driverAppPay + depinReward),
    distanceKm: km,
    durationMin: min,
    customerFeePct: KAIRO_CUSTOMER_FEE_PCT,
    driverMultiplier: KAIRO_DRIVER_MULTIPLIER,
  };
}
