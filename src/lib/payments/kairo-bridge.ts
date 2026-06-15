/**
 * Bridge between Kairo marketplace orders and the payments ledger.
 */

import { createTransaction, updateTransactionStatus } from "@/lib/ledger";
import { computeCustomerFee } from "@/lib/payments/fees";
import { computeDriverPayout } from "@/lib/payments/driver-payout";
import { emissionBreakdownWithLegacy } from "@/lib/payments/great-delta";

export interface KairoOrderSettlement {
  orderId: string;
  customerUserId: string;
  driverUserId: string;
  fareAmount: string;
  currency: string;
  depinRewards?: string;
  instantCashout?: boolean;
}

export async function settleKairoOrder(input: KairoOrderSettlement) {
  const fee = computeCustomerFee(input.fareAmount);
  const driver = computeDriverPayout({
    baseAmount: input.fareAmount,
    depinRewards: input.depinRewards,
    instantCashout: input.instantCashout,
  });

  const customerTx = await createTransaction({
    userId: input.customerUserId,
    direction: "withdrawal",
    rail: "square",
    amount: fee.grossAmount,
    currency: input.currency,
    status: "completed",
    metadata: {
      kairoOrderId: input.orderId,
      type: "kairo_fare",
      feeAmount: fee.feeAmount,
      feePercent: fee.feePercent,
      greatDeltaEmission: emissionBreakdownWithLegacy(fee.feeAmount),
    },
  });

  const driverTx = await createTransaction({
    userId: input.driverUserId,
    direction: "deposit",
    rail: "square",
    amount: driver.netPayout,
    currency: input.currency,
    status: "completed",
    metadata: {
      kairoOrderId: input.orderId,
      type: "kairo_driver_payout",
      multiplier: driver.multiplier,
      grossPayout: driver.grossPayout,
      depinRewards: driver.depinRewards,
      instantCashoutFee: driver.instantCashoutFee,
    },
  });

  return { customerTx, driverTx, fee, driver };
}

export async function creditDepositWithFee(input: {
  userId: string;
  rail: "square" | "wise" | "web3";
  grossAmount: string;
  currency: string;
  externalId?: string;
  metadata?: Record<string, unknown>;
}) {
  const fee = computeCustomerFee(input.grossAmount);
  const tx = await createTransaction({
    userId: input.userId,
    direction: "deposit",
    rail: input.rail,
    amount: fee.netAmount,
    currency: input.currency,
    status: "completed",
    externalId: input.externalId,
    metadata: {
      ...input.metadata,
      grossAmount: fee.grossAmount,
      platformFee: fee.feeAmount,
      feePercent: fee.feePercent,
      greatDeltaEmission: emissionBreakdownWithLegacy(fee.feeAmount),
    },
  });
  return { tx, fee };
}
