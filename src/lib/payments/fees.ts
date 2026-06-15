/**
 * YieldSwarm / Kairo customer payment fee — flat 1% added on top of credit amount.
 *
 * The customer enters how much they want credited to their balance. We charge
 * credit + 1% platform fee via Stripe.
 */

import { addAmounts, normalizeAmount, toScaled, fromScaled } from "@/lib/money";

/** 1% flat platform fee on customer payments. */
export const PLATFORM_FEE_RATE = "0.01";

const SCALE_FACTOR = 10n ** 18n;

export interface CustomerPaymentBreakdown {
  /** Amount credited to the user's balance after settlement. */
  creditAmount: string;
  /** 1% platform fee charged to the customer. */
  platformFee: string;
  /** Total charged on the payment method (credit + fee). */
  totalCharge: string;
  feeRate: string;
}

export function multiplyRate(amount: string, rate: string): string {
  const product = (toScaled(amount) * toScaled(rate)) / SCALE_FACTOR;
  return fromScaled(product);
}

export function calculateCustomerPayment(creditAmount: string): CustomerPaymentBreakdown {
  const credit = normalizeAmount(creditAmount);
  const platformFee = multiplyRate(credit, PLATFORM_FEE_RATE);
  const totalCharge = addAmounts(credit, platformFee);
  return {
    creditAmount: credit,
    platformFee,
    totalCharge,
    feeRate: PLATFORM_FEE_RATE,
  };
}
