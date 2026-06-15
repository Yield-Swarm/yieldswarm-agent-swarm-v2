/**
 * Fixed-point decimal money helpers.
 *
 * Amounts are passed around as human-readable decimal strings (e.g. "10.50")
 * together with a currency code. Internally we use BigInt scaled to 18 decimal
 * places so we never lose precision to floating point — important for both
 * fiat (cents) and crypto (up to 18 decimals).
 */

const SCALE = 18n;
const SCALE_FACTOR = 10n ** SCALE;

export type Money = { amount: string; currency: string };

export function toScaled(amount: string | number): bigint {
  const s = typeof amount === "number" ? amount.toString() : amount.trim();
  if (!/^-?\d+(\.\d+)?$/.test(s)) {
    throw new Error(`Invalid amount: ${amount}`);
  }
  const negative = s.startsWith("-");
  const unsigned = negative ? s.slice(1) : s;
  const [whole, frac = ""] = unsigned.split(".");
  const fracPadded = (frac + "0".repeat(Number(SCALE))).slice(0, Number(SCALE));
  const scaled = BigInt(whole) * SCALE_FACTOR + BigInt(fracPadded || "0");
  return negative ? -scaled : scaled;
}

export function fromScaled(scaled: bigint): string {
  const negative = scaled < 0n;
  const abs = negative ? -scaled : scaled;
  const whole = abs / SCALE_FACTOR;
  const frac = abs % SCALE_FACTOR;
  let fracStr = frac.toString().padStart(Number(SCALE), "0").replace(/0+$/, "");
  const result = fracStr.length ? `${whole}.${fracStr}` : `${whole}`;
  return negative ? `-${result}` : result;
}

export function addAmounts(a: string, b: string): string {
  return fromScaled(toScaled(a) + toScaled(b));
}

export function subAmounts(a: string, b: string): string {
  return fromScaled(toScaled(a) - toScaled(b));
}

export function gte(a: string, b: string): boolean {
  return toScaled(a) >= toScaled(b);
}

export function isPositive(a: string): boolean {
  return toScaled(a) > 0n;
}

export function normalizeAmount(a: string | number): string {
  return fromScaled(toScaled(a));
}

/** Convert a decimal amount to integer minor units (e.g. cents) for an API. */
export function toMinorUnits(amount: string, decimals: number): string {
  const factor = 10n ** BigInt(decimals);
  const scaled = toScaled(amount);
  // scaled is at 18 decimals; rescale to `decimals`
  const diff = SCALE - BigInt(decimals);
  const value =
    diff >= 0n ? scaled / 10n ** diff : scaled * 10n ** (-diff);
  return value.toString();
  // (factor referenced for clarity of intent)
  void factor;
}

/** Convert integer minor units back to a decimal string. */
export function fromMinorUnits(minor: string | number | bigint, decimals: number): string {
  const value = BigInt(minor);
  const scaled = value * 10n ** (SCALE - BigInt(decimals));
  return fromScaled(scaled);
}

export const FIAT_DECIMALS: Record<string, number> = {
  USD: 2,
  EUR: 2,
  GBP: 2,
  CAD: 2,
  AUD: 2,
};

export function fiatDecimals(currency: string): number {
  return FIAT_DECIMALS[currency.toUpperCase()] ?? 2;
}
