/**
 * Customer fee engine — 1% flat fee on deposits (Kairo marketplace).
 */

import { normalizeAmount, subAmounts } from "@/lib/money";
import { serverEnv } from "@/lib/config/env";

export interface FeeBreakdown {
  grossAmount: string;
  feeAmount: string;
  netAmount: string;
  feePercent: number;
}

export function customerFeePercent(): number {
  const raw = serverEnv.payments.customerFeePercent();
  return raw > 0 ? raw : 0.01;
}

export function computeCustomerFee(amount: string): FeeBreakdown {
  const feePercent = customerFeePercent();
  const gross = normalizeAmount(amount);
  const feeAmount = normalizeAmount((parseFloat(gross) * feePercent).toFixed(8));
  const netAmount = subAmounts(gross, feeAmount);
  return { grossAmount: gross, feeAmount, netAmount, feePercent };
}
