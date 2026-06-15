/** Small, dependency-free formatting helpers shared across adapters and UI. */
import type { AmountInput } from "./types";

/** Convert a human readable amount to the smallest unit using `decimals`. */
export function toBaseUnits(amount: AmountInput, decimals: number): bigint {
  if (typeof amount === "bigint") return amount;
  const str = String(amount).trim();
  if (!str || Number.isNaN(Number(str))) {
    throw new Error(`Invalid amount: ${amount}`);
  }
  const negative = str.startsWith("-");
  const clean = negative ? str.slice(1) : str;
  const [whole, fraction = ""] = clean.split(".");
  const paddedFraction = (fraction + "0".repeat(decimals)).slice(0, decimals);
  const combined = `${whole}${paddedFraction}`.replace(/^0+(?=\d)/, "");
  const value = BigInt(combined || "0");
  return negative ? -value : value;
}

/** Convert a smallest-unit value back to a human readable decimal string. */
export function fromBaseUnits(value: bigint, decimals: number): string {
  const negative = value < 0n;
  const abs = negative ? -value : value;
  const base = 10n ** BigInt(decimals);
  const whole = abs / base;
  const fraction = abs % base;
  let fractionStr = fraction.toString().padStart(decimals, "0");
  fractionStr = fractionStr.replace(/0+$/, "");
  const out = fractionStr ? `${whole}.${fractionStr}` : whole.toString();
  return negative ? `-${out}` : out;
}

/** Format a base-unit value to a fixed number of significant fractional digits. */
export function formatBalance(
  value: bigint,
  decimals: number,
  maxFractionDigits = 6,
): string {
  const full = fromBaseUnits(value, decimals);
  const [whole, fraction] = full.split(".");
  if (!fraction) return whole;
  const trimmed = fraction.slice(0, maxFractionDigits).replace(/0+$/, "");
  return trimmed ? `${whole}.${trimmed}` : whole;
}

/** Truncate an address: 0x1234…abcd. Works for any ecosystem string. */
export function shortenAddress(address: string, chars = 4): string {
  if (!address) return "";
  if (address.length <= chars * 2 + 3) return address;
  return `${address.slice(0, chars + 2)}…${address.slice(-chars)}`;
}
