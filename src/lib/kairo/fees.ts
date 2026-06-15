/**
 * Kairo fee model:
 * - Customers pay a flat 1% platform fee on each trip fare.
 * - Drivers receive 2× the base pay component (incentive multiplier).
 * - Instant cashout optionally deducts a small processing fee.
 */

export const CUSTOMER_FEE_RATE = 0.01;
export const DRIVER_PAY_MULTIPLIER = 2;
export const INSTANT_CASHOUT_FEE_RATE = 0.015;

export interface TripFeeBreakdown {
  fareAmount: string;
  customerFee: string;
  customerTotal: string;
  driverBasePay: string;
  driverPay: string;
  platformRevenue: string;
}

function dec(n: number): string {
  return n.toFixed(2);
}

export function parseAmount(amount: string): number {
  const n = parseFloat(amount);
  if (!Number.isFinite(n) || n < 0) throw new Error("Invalid amount");
  return n;
}

/** Compute trip fees from the quoted fare (pre-fee). */
export function computeTripFees(fareAmount: string): TripFeeBreakdown {
  const fare = parseAmount(fareAmount);
  const customerFee = fare * CUSTOMER_FEE_RATE;
  const customerTotal = fare + customerFee;
  const driverBasePay = fare * 0.75;
  const driverPay = driverBasePay * DRIVER_PAY_MULTIPLIER;
  const platformRevenue = customerFee + (fare - driverBasePay);

  return {
    fareAmount: dec(fare),
    customerFee: dec(customerFee),
    customerTotal: dec(customerTotal),
    driverBasePay: dec(driverBasePay),
    driverPay: dec(driverPay),
    platformRevenue: dec(platformRevenue),
  };
}

export function computeCashoutFee(amount: string, instant = true): string {
  const base = parseAmount(amount);
  if (!instant) return "0.00";
  return dec(base * INSTANT_CASHOUT_FEE_RATE);
}

export function netCashoutAmount(amount: string, instant = true): string {
  const base = parseAmount(amount);
  const fee = parseFloat(computeCashoutFee(amount, instant));
  return dec(Math.max(0, base - fee));
}
