/**
 * Kairo fee model — customer 1% flat platform fee, driver 2× base pay with
 * optional instant cashout surcharge.
 */

export const KAIRO_CUSTOMER_PLATFORM_FEE_BPS = 100; // 1%
export const KAIRO_DRIVER_PAY_MULTIPLIER = 2;
export const KAIRO_INSTANT_CASHOUT_FEE_BPS = 150; // 1.5% on instant payout

export interface TripQuoteInput {
  /** Trip fare before fees, in major currency units (e.g. dollars). */
  baseFare: string;
  currency?: string;
}

export interface TripQuote {
  currency: string;
  baseFare: string;
  customerPlatformFee: string;
  customerTotal: string;
  driverBasePay: string;
  driverBonusPay: string;
  driverGrossPay: string;
  depinRewardEstimate: string;
}

export interface DriverSettlementInput extends TripQuoteInput {
  driverId: string;
  instantCashout?: boolean;
  depinRewardWeight?: number;
}

export interface DriverSettlement extends TripQuote {
  driverId: string;
  instantCashout: boolean;
  instantCashoutFee: string;
  driverNetPay: string;
  appRevenue: string;
  cryptoRewardEstimate: string;
  breakdown: {
    appRevenue: string;
    depinRewards: string;
    driverPay: string;
  };
}

function toCents(amount: string): bigint {
  const [whole, frac = ""] = amount.split(".");
  const normalized = `${whole}${frac.padEnd(2, "0").slice(0, 2)}`;
  return BigInt(normalized.replace(/^(-?)0+(?=\d)/, "$1") || "0");
}

function fromCents(cents: bigint): string {
  const neg = cents < 0n;
  const abs = neg ? -cents : cents;
  const whole = abs / 100n;
  const frac = (abs % 100n).toString().padStart(2, "0");
  return `${neg ? "-" : ""}${whole}.${frac}`;
}

function mulBps(amount: bigint, bps: number): bigint {
  return (amount * BigInt(bps)) / 10_000n;
}

export function quoteTrip(input: TripQuoteInput): TripQuote {
  const currency = (input.currency ?? "USD").toUpperCase();
  const base = toCents(input.baseFare);
  const customerPlatformFee = mulBps(base, KAIRO_CUSTOMER_PLATFORM_FEE_BPS);
  const customerTotal = base + customerPlatformFee;
  const driverBasePay = base;
  const driverBonusPay = base; // 2× total = base + bonus
  const driverGrossPay = driverBasePay + driverBonusPay;
  const depinRewardEstimate = mulBps(base, 50); // 0.5% illustrative DePIN accrual

  return {
    currency,
    baseFare: fromCents(base),
    customerPlatformFee: fromCents(customerPlatformFee),
    customerTotal: fromCents(customerTotal),
    driverBasePay: fromCents(driverBasePay),
    driverBonusPay: fromCents(driverBonusPay),
    driverGrossPay: fromCents(driverGrossPay),
    depinRewardEstimate: fromCents(depinRewardEstimate),
  };
}

export function settleDriverTrip(input: DriverSettlementInput): DriverSettlement {
  const quote = quoteTrip(input);
  const base = toCents(input.baseFare);
  const driverGross = toCents(quote.driverGrossPay);
  const instant = Boolean(input.instantCashout);
  const instantFee = instant ? mulBps(driverGross, KAIRO_INSTANT_CASHOUT_FEE_BPS) : 0n;
  const driverNet = driverGross - instantFee;
  const weight = input.depinRewardWeight ?? 1;
  const depinRewards = mulBps(base, Math.round(50 * weight));
  const appRevenue = toCents(quote.customerPlatformFee);

  return {
    ...quote,
    driverId: input.driverId,
    instantCashout: instant,
    instantCashoutFee: fromCents(instantFee),
    driverNetPay: fromCents(driverNet),
    appRevenue: fromCents(appRevenue),
    cryptoRewardEstimate: fromCents(depinRewards),
    breakdown: {
      appRevenue: fromCents(appRevenue),
      depinRewards: fromCents(depinRewards),
      driverPay: fromCents(driverNet),
    },
  };
}
