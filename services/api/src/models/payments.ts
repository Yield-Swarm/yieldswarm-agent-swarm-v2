/**
 * Payment rails models — Square + Wise + Web3 unified wallet.
 */

export interface CustomerPayment {
  id: string;
  tripId: string;
  customerId: string;
  baseAmountCents: number;
  feePercent: number;
  feeAmountCents: number;
  totalAmountCents: number;
  provider: 'square' | 'wise';
  status: 'pending' | 'completed' | 'failed' | 'refunded';
  createdAt: string;
}

export interface DriverEarnings {
  driverId: string;
  tripId: string;
  basePayCents: number;
  multiplier: number;
  totalPayCents: number;
  instantCashout: boolean;
  cashoutFeeCents: number;
  breakdown: EarningsBreakdown;
  status: 'pending' | 'paid' | 'cashout_pending';
}

export interface EarningsBreakdown {
  appRevenueCents: number;
  depinRewardsCents: number;
  cryptoRewardsCents: number;
  totalCents: number;
}

export interface WebhookEvent {
  id: string;
  provider: 'square' | 'wise';
  eventType: string;
  payload: Record<string, unknown>;
  verified: boolean;
  processedAt: string | null;
}

export interface UnifiedWallet {
  driverId: string;
  evmAddress: string;
  solanaAddress?: string;
  tonAddress?: string;
  balances: WalletBalances;
}

export interface WalletBalances {
  usdCents: number;
  apnTokens: number;
  ethWei: string;
  pendingDepinRewards: number;
}

export const CUSTOMER_FEE_PERCENT = 0.01;
export const DRIVER_PAY_MULTIPLIER = 2.0;
export const INSTANT_CASHOUT_FEE_PERCENT = 0.015;
