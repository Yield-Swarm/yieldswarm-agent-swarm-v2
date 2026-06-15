/** Domain models for the payments subsystem. */

export type Chain = "evm" | "solana" | "ton";

export type PaymentRail = "square" | "wise" | "web3";

export type TxDirection = "deposit" | "withdrawal";

export type TxStatus =
  | "pending" // created, awaiting external confirmation
  | "processing" // funds moving (e.g. broadcast on-chain / Wise transfer funded)
  | "completed" // settled, balance credited/debited
  | "failed"
  | "cancelled";

export interface User {
  id: string;
  email: string;
  createdAt: string;
}

export interface LinkedWallet {
  id: string;
  userId: string;
  chain: Chain;
  address: string; // normalized (lowercase for evm)
  label?: string;
  verifiedAt: string;
}

export interface Transaction {
  id: string;
  userId: string;
  direction: TxDirection;
  rail: PaymentRail;
  status: TxStatus;
  amount: string; // decimal string
  currency: string; // USD, EUR, ETH, SOL, USDC, TON, ...
  /** External reference, e.g. Square payment id, Wise transfer id, tx hash. */
  externalId?: string;
  /** Idempotency / correlation key we generated when creating the intent. */
  reference: string;
  chain?: Chain;
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

/** Tracks on-chain deposit intents we are watching for confirmation. */
export interface OnchainDepositIntent {
  id: string;
  userId: string;
  reference: string;
  chain: Chain;
  asset: string; // ETH / SOL / TON / USDC etc.
  expectedAmount?: string;
  depositAddress: string; // treasury address funds should arrive at
  fromAddress?: string;
  txHash?: string;
  status: TxStatus;
  createdAt: string;
  updatedAt: string;
}

export interface ProcessedWebhookEvent {
  id: string; // provider event id
  provider: PaymentRail;
  receivedAt: string;
}

export interface DB {
  users: Record<string, User>;
  wallets: Record<string, LinkedWallet>;
  transactions: Record<string, Transaction>;
  depositIntents: Record<string, OnchainDepositIntent>;
  webhookEvents: Record<string, ProcessedWebhookEvent>;
  /** Convenience index: per-user, per-currency available balance (decimal str). */
  balances: Record<string, Record<string, string>>;
}

export function emptyDB(): DB {
  return {
    users: {},
    wallets: {},
    transactions: {},
    depositIntents: {},
    webhookEvents: {},
    balances: {},
  };
}
