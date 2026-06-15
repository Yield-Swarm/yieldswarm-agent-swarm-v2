/**
 * Customer fee engine — supports both:
 * - Kairo marketplace fee (deducted from gross)
 * - Stripe customer payments (1% added on top of credit amount)
 */

import { addAmounts, normalizeAmount, subAmounts, toScaled, fromScaled } from "@/lib/money";
import { serverEnv } from "@/lib/config/env";

/** 1% flat platform fee on Stripe customer payments. */
export const PLATFORM_FEE_RATE = "0.01";

const SCALE_FACTOR = 10n ** 18n;

export interface FeeBreakdown {
  grossAmount: string;
  feeAmount: string;
  netAmount: string;
  feePercent: number;
}

export interface CustomerPaymentBreakdown {
  /** Amount credited to the user's balance after settlement. */
  creditAmount: string;
  /** 1% platform fee charged to the customer. */
  platformFee: string;
  /** Total charged on the payment method (credit + fee). */
  totalCharge: string;
  feeRate: string;
}

export function customerFeePercent(): number {
  const raw = serverEnv.payments.customerFeePercent();
  return raw > 0 ? raw : 0.01;
}

/** Kairo marketplace fee — deducted from gross deposit. */
export function computeCustomerFee(amount: string): FeeBreakdown {
  const feePercent = customerFeePercent();
  const gross = normalizeAmount(amount);
  const feeAmount = normalizeAmount((parseFloat(gross) * feePercent).toFixed(8));
  const netAmount = subAmounts(gross, feeAmount);
  return { grossAmount: gross, feeAmount, netAmount, feePercent };
}

export function multiplyRate(amount: string, rate: string): string {
  const product = (toScaled(amount) * toScaled(rate)) / SCALE_FACTOR;
  return fromScaled(product);
}

/** Stripe fee — customer pays credit + 1% platform fee. */
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
