/**
 * Square integration — fiat deposits via card and ACH bank transfer.
 *
 * Two complementary entry points:
 *   1. createCardCheckoutLink(): a hosted Square Checkout payment link. Best for
 *      card / digital-wallet deposits — we redirect the user to Square's page.
 *   2. createDirectPayment(): server-side Payments API call using a token from
 *      the Square Web Payments SDK on the client. This path supports BOTH card
 *      tokens and ACH bank-transfer tokens (Square `ach()` -> Plaid -> token).
 *
 * Settlement is driven by the verified webhook (`payment.created/updated`),
 * which credits the user's balance exactly once when the payment COMPLETES.
 */

import { Client, Environment, WebhooksHelper } from "square";
import { serverEnv } from "@/lib/config/env";
import { toMinorUnits, fromMinorUnits, fiatDecimals } from "@/lib/money";

let cached: Client | null = null;

export function getSquareClient(): Client {
  const accessToken = serverEnv.square.accessToken();
  if (!accessToken) {
    throw new Error("Square is not configured (missing SQUARE_ACCESS_TOKEN)");
  }
  if (!cached) {
    cached = new Client({
      accessToken,
      environment:
        serverEnv.square.environment() === "production"
          ? Environment.Production
          : Environment.Sandbox,
    });
  }
  return cached;
}

function moneyAmount(amount: string, currency: string): bigint {
  return BigInt(toMinorUnits(amount, fiatDecimals(currency)));
}

export interface CardCheckoutInput {
  amount: string;
  currency: string;
  reference: string;
  description?: string;
  redirectUrl?: string;
  buyerEmail?: string;
}

export interface CardCheckoutResult {
  url: string;
  paymentLinkId: string;
  orderId?: string;
}

export async function createCardCheckoutLink(
  input: CardCheckoutInput,
): Promise<CardCheckoutResult> {
  const client = getSquareClient();
  const locationId = serverEnv.square.locationId();
  if (!locationId) throw new Error("Square is not configured (missing SQUARE_LOCATION_ID)");

  const currency = input.currency.toUpperCase();
  const res = await client.checkoutApi.createPaymentLink({
    idempotencyKey: input.reference,
    quickPay: {
      name: input.description ?? "YieldSwarm deposit",
      priceMoney: { amount: moneyAmount(input.amount, currency), currency },
      locationId,
    },
    checkoutOptions: {
      redirectUrl: input.redirectUrl ?? `${serverEnv.appUrl}/payments?square=return`,
      askForShippingAddress: false,
    },
    paymentNote: `yieldswarm:${input.reference}`,
    prePopulatedData: input.buyerEmail ? { buyerEmail: input.buyerEmail } : undefined,
  });

  const link = res.result.paymentLink;
  if (!link?.url || !link.id) {
    throw new Error("Square did not return a payment link URL");
  }
  return { url: link.url, paymentLinkId: link.id, orderId: link.orderId };
}

export interface DirectPaymentInput {
  /** Token from the Web Payments SDK — a card nonce or an ACH bank token. */
  sourceId: string;
  /** SCA verification token (3DS) when present; optional for ACH. */
  verificationToken?: string;
  amount: string;
  currency: string;
  reference: string;
  buyerEmail?: string;
  /** "CARD" | "ACH" — informational, lets us tag the transaction. */
  method?: "CARD" | "ACH";
}

export interface DirectPaymentResult {
  paymentId: string;
  status: string; // APPROVED | COMPLETED | PENDING | FAILED | CANCELED
  orderId?: string;
  receiptUrl?: string;
}

export async function createDirectPayment(
  input: DirectPaymentInput,
): Promise<DirectPaymentResult> {
  const client = getSquareClient();
  const locationId = serverEnv.square.locationId();
  if (!locationId) throw new Error("Square is not configured (missing SQUARE_LOCATION_ID)");

  const currency = input.currency.toUpperCase();
  const res = await client.paymentsApi.createPayment({
    idempotencyKey: input.reference,
    sourceId: input.sourceId,
    verificationToken: input.verificationToken,
    locationId,
    amountMoney: { amount: moneyAmount(input.amount, currency), currency },
    referenceId: input.reference,
    note: `yieldswarm:${input.reference}${input.method ? `:${input.method}` : ""}`,
    buyerEmailAddress: input.buyerEmail,
    // ACH settles asynchronously; this lets Square accept the deferred payment.
    autocomplete: true,
  });

  const payment = res.result.payment;
  if (!payment?.id) throw new Error("Square did not return a payment");
  return {
    paymentId: payment.id,
    status: payment.status ?? "PENDING",
    orderId: payment.orderId,
    receiptUrl: payment.receiptUrl,
  };
}

export async function getPayment(paymentId: string) {
  const client = getSquareClient();
  const res = await client.paymentsApi.getPayment(paymentId);
  return res.result.payment ?? null;
}

/** Verify a Square webhook delivery signature (HMAC over url + raw body). */
export function verifySquareWebhook(rawBody: string, signature: string | null): boolean {
  const key = serverEnv.square.webhookSignatureKey();
  const url = serverEnv.square.webhookNotificationUrl();
  if (!key || !signature) return false;
  try {
    return WebhooksHelper.isValidWebhookEventSignature(rawBody, signature, key, url);
  } catch {
    return false;
  }
}

/** Extract a normalized decimal amount from a Square Money object. */
export function squareMoneyToDecimal(
  money: { amount?: bigint | number | null; currency?: string | null } | undefined | null,
): { amount: string; currency: string } | null {
  if (!money || money.amount == null || !money.currency) return null;
  const currency = money.currency;
  return {
    amount: fromMinorUnits(money.amount.toString(), fiatDecimals(currency)),
    currency,
  };
}
