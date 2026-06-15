import { createHmac, timingSafeEqual } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import type {
  CustomerPayment,
  DriverEarnings,
  WebhookEvent,
  UnifiedWallet,
  EarningsBreakdown,
} from '../models/payments.js';
import {
  CUSTOMER_FEE_PERCENT,
  DRIVER_PAY_MULTIPLIER,
  INSTANT_CASHOUT_FEE_PERCENT,
} from '../models/payments.js';
import { getDriver } from './kairo-identity.js';

const payments: CustomerPayment[] = [];
const earnings: DriverEarnings[] = [];
const webhooks: WebhookEvent[] = [];

export function processCustomerPayment(params: {
  tripId: string;
  customerId: string;
  baseAmountCents: number;
  provider?: 'square' | 'wise';
}): CustomerPayment {
  const feeAmountCents = Math.round(params.baseAmountCents * CUSTOMER_FEE_PERCENT);
  const payment: CustomerPayment = {
    id: uuidv4(),
    tripId: params.tripId,
    customerId: params.customerId,
    baseAmountCents: params.baseAmountCents,
    feePercent: CUSTOMER_FEE_PERCENT,
    feeAmountCents,
    totalAmountCents: params.baseAmountCents + feeAmountCents,
    provider: params.provider || 'square',
    status: 'completed',
    createdAt: new Date().toISOString(),
  };
  payments.push(payment);
  return payment;
}

export function processDriverEarnings(params: {
  driverId: string;
  tripId: string;
  basePayCents: number;
  instantCashout?: boolean;
  depinRewardsCents?: number;
  cryptoRewardsCents?: number;
}): DriverEarnings {
  const totalPayCents = Math.round(params.basePayCents * DRIVER_PAY_MULTIPLIER);
  const depin = params.depinRewardsCents || 0;
  const crypto = params.cryptoRewardsCents || 0;
  const instant = params.instantCashout || false;
  const cashoutFee = instant
    ? Math.round(totalPayCents * INSTANT_CASHOUT_FEE_PERCENT)
    : 0;

  const breakdown: EarningsBreakdown = {
    appRevenueCents: totalPayCents,
    depinRewardsCents: depin,
    cryptoRewardsCents: crypto,
    totalCents: totalPayCents + depin + crypto - cashoutFee,
  };

  const record: DriverEarnings = {
    driverId: params.driverId,
    tripId: params.tripId,
    basePayCents: params.basePayCents,
    multiplier: DRIVER_PAY_MULTIPLIER,
    totalPayCents,
    instantCashout: instant,
    cashoutFeeCents: cashoutFee,
    breakdown,
    status: instant ? 'cashout_pending' : 'pending',
  };

  earnings.push(record);
  return record;
}

export function verifySquareWebhook(
  body: string,
  signature: string,
  webhookUrl: string
): boolean {
  const key = process.env.SQUARE_WEBHOOK_SIGNATURE_KEY || '';
  if (!key) return false;

  const payload = webhookUrl + body;
  const expected = createHmac('sha256', key).update(payload).digest('base64');

  try {
    return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  } catch {
    return false;
  }
}

export function verifyWiseWebhook(
  body: string,
  signature: string
): boolean {
  const secret = process.env.WISE_WEBHOOK_SECRET || '';
  if (!secret) return false;

  const expected = createHmac('sha256', secret).update(body).digest('hex');
  try {
    return timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
  } catch {
    return false;
  }
}

export function handleWebhook(
  provider: 'square' | 'wise',
  eventType: string,
  payload: Record<string, unknown>,
  verified: boolean
): WebhookEvent {
  const event: WebhookEvent = {
    id: uuidv4(),
    provider,
    eventType,
    payload,
    verified,
    processedAt: verified ? new Date().toISOString() : null,
  };
  webhooks.push(event);

  if (verified && eventType === 'payment.completed') {
    const amount = (payload.amount as number) || 0;
    processCustomerPayment({
      tripId: (payload.tripId as string) || uuidv4(),
      customerId: (payload.customerId as string) || 'unknown',
      baseAmountCents: amount,
      provider,
    });
  }

  return event;
}

export function getUnifiedWallet(driverId: string): UnifiedWallet | null {
  const driver = getDriver(driverId);
  if (!driver) return null;

  const driverEarnings = earnings.filter((e) => e.driverId === driverId);
  const totalUsd = driverEarnings.reduce(
    (sum, e) => sum + e.breakdown.totalCents,
    0
  );

  return {
    driverId,
    evmAddress: driver.evmAddress,
    balances: {
      usdCents: totalUsd,
      apnTokens: Math.floor(totalUsd / 100),
      ethWei: '0',
      pendingDepinRewards: driverEarnings.reduce(
        (sum, e) => sum + e.breakdown.depinRewardsCents,
        0
      ),
    },
  };
}

export function getDriverEarningsHistory(driverId: string): DriverEarnings[] {
  return earnings.filter((e) => e.driverId === driverId);
}

export function getPaymentStats() {
  return {
    totalPayments: payments.length,
    totalRevenueCents: payments.reduce((s, p) => s + p.feeAmountCents, 0),
    totalDriverPayoutsCents: earnings.reduce(
      (s, e) => s + e.breakdown.totalCents,
      0
    ),
    webhooksProcessed: webhooks.filter((w) => w.verified).length,
    customerFeePercent: CUSTOMER_FEE_PERCENT,
    driverMultiplier: DRIVER_PAY_MULTIPLIER,
  };
}
