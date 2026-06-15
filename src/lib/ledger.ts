/**
 * Ledger service: the single place that mutates user balances and writes
 * transaction records. All rails (Square, Wise, Web3) funnel through here so
 * crediting/debiting stays consistent and idempotent.
 */

import { store } from "@/lib/db/store";
import {
  Chain,
  DB,
  PaymentRail,
  Transaction,
  TxDirection,
  TxStatus,
} from "@/lib/db/models";
import { addAmounts, gte, subAmounts, isPositive } from "@/lib/money";
import { nowIso, reference, uuid } from "@/lib/ids";
import { computeCustomerFee } from "@/lib/payments/fees";

export interface CreateTxInput {
  userId: string;
  direction: TxDirection;
  rail: PaymentRail;
  amount: string;
  currency: string;
  status?: TxStatus;
  externalId?: string;
  reference?: string;
  chain?: Chain;
  metadata?: Record<string, unknown>;
}

export async function createTransaction(input: CreateTxInput): Promise<Transaction> {
  return store.mutate((db) => {
    const id = uuid();
    const ref = input.reference ?? reference(input.direction === "deposit" ? "dep" : "wd");
    const tx: Transaction = {
      id,
      userId: input.userId,
      direction: input.direction,
      rail: input.rail,
      status: input.status ?? "pending",
      amount: input.amount,
      currency: input.currency.toUpperCase(),
      externalId: input.externalId,
      reference: ref,
      chain: input.chain,
      metadata: input.metadata,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.transactions[id] = tx;
    // If the caller created an already-completed tx, settle it immediately.
    if (tx.status === "completed") {
      applyToBalance(db, tx);
    }
    return tx;
  });
}

/**
 * Transition a transaction to a new status. Crediting/debiting the balance
 * happens exactly once, when the tx first becomes "completed".
 */
export async function updateTransactionStatus(
  txId: string,
  status: TxStatus,
  patch: Partial<Pick<Transaction, "externalId" | "metadata">> = {},
): Promise<Transaction | null> {
  return store.mutate((db) => {
    const tx = db.transactions[txId];
    if (!tx) return null;
    const wasCompleted = tx.status === "completed";
    tx.status = status;
    if (patch.externalId) tx.externalId = patch.externalId;
    if (patch.metadata) tx.metadata = { ...(tx.metadata ?? {}), ...patch.metadata };
    tx.updatedAt = nowIso();
    if (status === "completed" && !wasCompleted) {
      applyToBalance(db, tx);
    }
    return tx;
  });
}

export async function findByReference(ref: string): Promise<Transaction | null> {
  const db = await store.read();
  return Object.values(db.transactions).find((t) => t.reference === ref) ?? null;
}

export async function findByExternalId(
  rail: PaymentRail,
  externalId: string,
): Promise<Transaction | null> {
  const db = await store.read();
  return (
    Object.values(db.transactions).find(
      (t) => t.rail === rail && t.externalId === externalId,
    ) ?? null
  );
}

function applyToBalance(db: DB, tx: Transaction): void {
  const userBalances = db.balances[tx.userId] ?? (db.balances[tx.userId] = {});
  const current = userBalances[tx.currency] ?? "0";
  let amount = tx.amount;

  // Apply 1% customer fee on deposits unless already netted in metadata.
  if (
    tx.direction === "deposit" &&
    !tx.metadata?.grossAmount &&
    !tx.metadata?.platformFee &&
    !tx.metadata?.type?.toString().startsWith("kairo_")
  ) {
    const fee = computeCustomerFee(tx.amount);
    amount = fee.netAmount;
    tx.metadata = {
      ...(tx.metadata ?? {}),
      grossAmount: fee.grossAmount,
      platformFee: fee.feeAmount,
      feePercent: fee.feePercent,
    };
    tx.amount = amount;
  }

  userBalances[tx.currency] =
    tx.direction === "deposit"
      ? addAmounts(current, amount)
      : subAmounts(current, amount);
}

export async function getBalances(userId: string): Promise<Record<string, string>> {
  const db = await store.read();
  return db.balances[userId] ?? {};
}

export async function getBalance(userId: string, currency: string): Promise<string> {
  const balances = await getBalances(userId);
  return balances[currency.toUpperCase()] ?? "0";
}

export async function hasSufficientBalance(
  userId: string,
  currency: string,
  amount: string,
): Promise<boolean> {
  if (!isPositive(amount)) return false;
  const bal = await getBalance(userId, currency);
  return gte(bal, amount);
}

/**
 * Atomically reserve funds for a withdrawal: within a single store mutation we
 * check the balance and immediately debit it, writing a "processing" tx. This
 * prevents concurrent withdrawals from double-spending. If the external send
 * later fails, call `refundWithdrawal` to credit the funds back.
 */
export async function reserveWithdrawal(input: {
  userId: string;
  rail: PaymentRail;
  amount: string;
  currency: string;
  chain?: Chain;
  metadata?: Record<string, unknown>;
}): Promise<{ tx: Transaction } | { error: string }> {
  return store.mutate((db) => {
    const currency = input.currency.toUpperCase();
    if (!isPositive(input.amount)) return { error: "Amount must be positive" };
    const userBalances = db.balances[input.userId] ?? (db.balances[input.userId] = {});
    const current = userBalances[currency] ?? "0";
    if (!gte(current, input.amount)) {
      return { error: `Insufficient ${currency} balance` };
    }
    userBalances[currency] = subAmounts(current, input.amount);
    const id = uuid();
    const tx: Transaction = {
      id,
      userId: input.userId,
      direction: "withdrawal",
      rail: input.rail,
      status: "processing",
      amount: input.amount,
      currency,
      reference: reference("wd"),
      chain: input.chain,
      metadata: input.metadata,
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.transactions[id] = tx;
    return { tx };
  });
}

/** Mark a reserved withdrawal as completed (funds already debited at reserve). */
export async function completeWithdrawal(
  txId: string,
  patch: Partial<Pick<Transaction, "externalId" | "metadata">> = {},
): Promise<Transaction | null> {
  return store.mutate((db) => {
    const tx = db.transactions[txId];
    if (!tx) return null;
    tx.status = "completed";
    if (patch.externalId) tx.externalId = patch.externalId;
    if (patch.metadata) tx.metadata = { ...(tx.metadata ?? {}), ...patch.metadata };
    tx.updatedAt = nowIso();
    return tx;
  });
}

/** Credit funds back to a reserved withdrawal that ultimately failed. */
export async function refundWithdrawal(
  txId: string,
  reason: string,
): Promise<Transaction | null> {
  return store.mutate((db) => {
    const tx = db.transactions[txId];
    if (!tx || tx.status === "failed" || tx.status === "completed") return tx ?? null;
    const userBalances = db.balances[tx.userId] ?? (db.balances[tx.userId] = {});
    userBalances[tx.currency] = addAmounts(userBalances[tx.currency] ?? "0", tx.amount);
    tx.status = "failed";
    tx.metadata = { ...(tx.metadata ?? {}), refundReason: reason };
    tx.updatedAt = nowIso();
    return tx;
  });
}

export async function listTransactions(
  userId: string,
  limit = 50,
): Promise<Transaction[]> {
  const db = await store.read();
  return Object.values(db.transactions)
    .filter((t) => t.userId === userId)
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
    .slice(0, limit);
}
