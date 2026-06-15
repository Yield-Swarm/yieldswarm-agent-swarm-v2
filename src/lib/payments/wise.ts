/**
 * Wise (TransferWise) integration — fiat payouts/transfers (off-ramp) and
 * inbound payment requests (on-ramp).
 *
 * Off-ramp (withdraw to bank) follows the standard Wise flow:
 *   quote -> recipient account -> transfer -> fund (from Wise balance).
 *
 * On-ramp (deposit) uses Wise Payment Requests so a user can pay us; if the
 * profile has no payment-request capability we fall back to returning the
 * profile's receiving balance account details.
 *
 * Webhook deliveries are verified with Wise's RSA public key (RSA-SHA256 over
 * the raw request body).
 */

import { createVerify } from "node:crypto";
import { serverEnv } from "@/lib/config/env";

interface WiseRequestOpts {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  path: string;
  body?: unknown;
  query?: Record<string, string | number | undefined>;
}

async function wiseFetch<T>(opts: WiseRequestOpts): Promise<T> {
  const token = serverEnv.wise.apiToken();
  if (!token) throw new Error("Wise is not configured (missing WISE_API_TOKEN)");

  const url = new URL(opts.path, serverEnv.wise.apiBase());
  if (opts.query) {
    for (const [k, v] of Object.entries(opts.query)) {
      if (v !== undefined) url.searchParams.set(k, String(v));
    }
  }

  const res = await fetch(url.toString(), {
    method: opts.method ?? "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
    cache: "no-store",
  });

  const text = await res.text();
  const payload = text ? safeJson(text) : null;
  if (!res.ok) {
    const message =
      (payload && (payload.message || payload.errors?.[0]?.message)) ||
      `Wise API error ${res.status}`;
    throw new WiseError(message, res.status, payload);
  }
  return payload as T;
}

function safeJson(text: string): any {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

export class WiseError extends Error {
  constructor(
    message: string,
    public status: number,
    public payload: unknown,
  ) {
    super(message);
    this.name = "WiseError";
  }
}

function profileId(): string {
  const id = serverEnv.wise.profileId();
  if (!id) throw new Error("Wise is not configured (missing WISE_PROFILE_ID)");
  return id;
}

// ---------------------------------------------------------------------------
// Quotes
// ---------------------------------------------------------------------------

export interface CreateQuoteInput {
  sourceCurrency: string;
  targetCurrency: string;
  /** Provide exactly one of sourceAmount / targetAmount. */
  sourceAmount?: string;
  targetAmount?: string;
}

export interface WiseQuote {
  id: string;
  sourceCurrency: string;
  targetCurrency: string;
  sourceAmount: number;
  targetAmount: number;
  rate: number;
  paymentOptions?: unknown;
}

export async function createQuote(input: CreateQuoteInput): Promise<WiseQuote> {
  return wiseFetch<WiseQuote>({
    method: "POST",
    path: `/v3/profiles/${profileId()}/quotes`,
    body: {
      sourceCurrency: input.sourceCurrency.toUpperCase(),
      targetCurrency: input.targetCurrency.toUpperCase(),
      sourceAmount: input.sourceAmount ? Number(input.sourceAmount) : undefined,
      targetAmount: input.targetAmount ? Number(input.targetAmount) : undefined,
      payOut: "BANK_TRANSFER",
    },
  });
}

// ---------------------------------------------------------------------------
// Recipients
// ---------------------------------------------------------------------------

export interface CreateRecipientInput {
  currency: string;
  /** e.g. "iban", "aba", "sort_code", "email" */
  type: string;
  accountHolderName: string;
  details: Record<string, unknown>;
  legalType?: "PRIVATE" | "BUSINESS";
}

export interface WiseRecipient {
  id: number;
  accountHolderName: string;
  currency: string;
}

export async function createRecipient(input: CreateRecipientInput): Promise<WiseRecipient> {
  return wiseFetch<WiseRecipient>({
    method: "POST",
    path: `/v1/accounts`,
    body: {
      profile: Number(profileId()),
      currency: input.currency.toUpperCase(),
      type: input.type,
      accountHolderName: input.accountHolderName,
      legalType: input.legalType ?? "PRIVATE",
      details: input.details,
    },
  });
}

// ---------------------------------------------------------------------------
// Transfers
// ---------------------------------------------------------------------------

export interface CreateTransferInput {
  targetAccountId: number;
  quoteId: string;
  /** Idempotency key (UUID) — Wise dedupes on this. */
  customerTransactionId: string;
  reference?: string;
}

export interface WiseTransfer {
  id: number;
  status: string;
  targetAccount: number;
  quoteUuid: string;
  reference?: string;
}

export async function createTransfer(input: CreateTransferInput): Promise<WiseTransfer> {
  return wiseFetch<WiseTransfer>({
    method: "POST",
    path: `/v1/transfers`,
    body: {
      targetAccount: input.targetAccountId,
      quoteUuid: input.quoteId,
      customerTransactionId: input.customerTransactionId,
      details: {
        reference: (input.reference ?? "YieldSwarm").slice(0, 35),
        transferPurpose: "verification.transfers.purpose.pay.bills",
        sourceOfFunds: "verification.source.of.funds.other",
      },
    },
  });
}

/** Fund a created transfer from the Wise balance, completing the payout. */
export async function fundTransfer(transferId: number): Promise<{ status: string }> {
  return wiseFetch<{ status: string }>({
    method: "POST",
    path: `/v3/profiles/${profileId()}/transfers/${transferId}/payments`,
    body: { type: "BALANCE" },
  });
}

export async function getTransfer(transferId: number | string): Promise<WiseTransfer> {
  return wiseFetch<WiseTransfer>({ path: `/v1/transfers/${transferId}` });
}

/**
 * High-level off-ramp: quote -> recipient -> transfer -> fund.
 * Returns the created (and funded) transfer.
 */
export interface BankPayoutInput {
  amount: string; // in source currency
  sourceCurrency: string;
  targetCurrency: string;
  recipient: CreateRecipientInput;
  customerTransactionId: string;
  reference?: string;
  fund?: boolean; // default true
}

export interface BankPayoutResult {
  transferId: number;
  status: string;
  quoteId: string;
  recipientId: number;
  funded: boolean;
}

export async function createBankPayout(input: BankPayoutInput): Promise<BankPayoutResult> {
  const quote = await createQuote({
    sourceCurrency: input.sourceCurrency,
    targetCurrency: input.targetCurrency,
    sourceAmount: input.amount,
  });
  const recipient = await createRecipient(input.recipient);
  const transfer = await createTransfer({
    targetAccountId: recipient.id,
    quoteId: quote.id,
    customerTransactionId: input.customerTransactionId,
    reference: input.reference,
  });

  let funded = false;
  let status = transfer.status;
  if (input.fund !== false) {
    const result = await fundTransfer(transfer.id);
    status = result.status ?? status;
    funded = true;
  }

  return {
    transferId: transfer.id,
    status,
    quoteId: quote.id,
    recipientId: recipient.id,
    funded,
  };
}

// ---------------------------------------------------------------------------
// Inbound (deposit) — payment request, with account-details fallback
// ---------------------------------------------------------------------------

export interface PaymentRequestInput {
  amount: string;
  currency: string;
  reference: string;
  description?: string;
}

export interface PaymentRequestResult {
  kind: "payment_request" | "account_details";
  /** Hosted link the payer can use (payment_request) */
  link?: string;
  id?: string;
  /** Receiving account details fallback */
  accountDetails?: unknown;
}

export async function createPaymentRequest(
  input: PaymentRequestInput,
): Promise<PaymentRequestResult> {
  try {
    const res = await wiseFetch<any>({
      method: "POST",
      path: `/v1/profiles/${profileId()}/payment-requests`,
      body: {
        amount: { value: Number(input.amount), currency: input.currency.toUpperCase() },
        balanceId: undefined,
        description: input.description ?? "YieldSwarm deposit",
        reference: input.reference,
      },
    });
    return {
      kind: "payment_request",
      id: res?.id,
      link: res?.link ?? res?.paymentLink ?? res?.url,
    };
  } catch {
    // Fall back to returning receiving account details for a manual wire.
    const accounts = await wiseFetch<any>({
      path: `/v1/borderless-accounts`,
      query: { profileId: profileId() },
    }).catch(() => null);
    return { kind: "account_details", accountDetails: accounts };
  }
}

// ---------------------------------------------------------------------------
// Webhook verification (RSA-SHA256 with Wise public key)
// ---------------------------------------------------------------------------

export function verifyWiseWebhook(rawBody: string, signature: string | null): boolean {
  const publicKey = serverEnv.wise.webhookPublicKey();
  if (!publicKey || !signature) return false;
  try {
    const verifier = createVerify("RSA-SHA256");
    verifier.update(rawBody);
    verifier.end();
    return verifier.verify(normalizePem(publicKey), signature, "base64");
  } catch {
    return false;
  }
}

function normalizePem(key: string): string {
  // Allow the key to be provided with literal "\n" sequences (common in env vars).
  return key.includes("-----BEGIN") ? key.replace(/\\n/g, "\n") : key;
}
