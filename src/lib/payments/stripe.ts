/**
 * Stripe integration — customer payments with 1% platform fee.
 *
 * Supports:
 *   - Checkout Session (hosted redirect)
 *   - PaymentIntent + Elements (embedded card form)
 *
 * Settlement via verified webhook (`checkout.session.completed`,
 * `payment_intent.succeeded`). Credits the user's balance with the net
 * credit amount (excluding the 1% fee).
 */

import Stripe from "stripe";
import { serverEnv } from "@/lib/config/env";
import { calculateCustomerPayment } from "@/lib/payments/fees";
import { fiatDecimals, toMinorUnits } from "@/lib/money";

let cached: Stripe | null = null;

export function getStripeClient(): Stripe {
  const secretKey = serverEnv.stripe.secretKey();
  if (!secretKey) {
    throw new Error("Stripe is not configured (missing STRIPE_SECRET_KEY)");
  }
  if (!cached) {
    cached = new Stripe(secretKey, {
      apiVersion: "2024-06-20",
      typescript: true,
    });
  }
  return cached;
}

export interface StripeCheckoutInput {
  creditAmount: string;
  currency: string;
  reference: string;
  userId: string;
  description?: string;
  successUrl?: string;
  cancelUrl?: string;
  customerEmail?: string;
}

export interface StripeCheckoutResult {
  sessionId: string;
  url: string;
  breakdown: ReturnType<typeof calculateCustomerPayment>;
}

export async function createCheckoutSession(
  input: StripeCheckoutInput,
): Promise<StripeCheckoutResult> {
  const stripe = getStripeClient();
  const currency = input.currency.toLowerCase();
  const breakdown = calculateCustomerPayment(input.creditAmount);
  const decimals = fiatDecimals(currency);
  const unitAmount = Number(toMinorUnits(breakdown.totalCharge, decimals));

  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    success_url:
      input.successUrl ??
      `${serverEnv.appUrl}/payments?stripe=success&reference=${input.reference}`,
    cancel_url:
      input.cancelUrl ??
      `${serverEnv.appUrl}/payments?stripe=cancel&reference=${input.reference}`,
    customer_email: input.customerEmail,
    client_reference_id: input.reference,
    metadata: {
      reference: input.reference,
      userId: input.userId,
      creditAmount: breakdown.creditAmount,
      platformFee: breakdown.platformFee,
      totalCharge: breakdown.totalCharge,
      feeRate: breakdown.feeRate,
      rail: "stripe",
    },
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency,
          unit_amount: unitAmount,
          product_data: {
            name: input.description ?? "YieldSwarm payment",
            description: `Credit ${breakdown.creditAmount} ${currency.toUpperCase()} (+ 1% platform fee)`,
          },
        },
      },
    ],
    payment_intent_data: {
      metadata: {
        reference: input.reference,
        userId: input.userId,
        creditAmount: breakdown.creditAmount,
        platformFee: breakdown.platformFee,
        totalCharge: breakdown.totalCharge,
        feeRate: breakdown.feeRate,
      },
    },
  });

  if (!session.url || !session.id) {
    throw new Error("Stripe did not return a checkout session URL");
  }

  return { sessionId: session.id, url: session.url, breakdown };
}

export interface StripePaymentIntentInput {
  creditAmount: string;
  currency: string;
  reference: string;
  userId: string;
  description?: string;
}

export interface StripePaymentIntentResult {
  paymentIntentId: string;
  clientSecret: string;
  breakdown: ReturnType<typeof calculateCustomerPayment>;
}

export async function createPaymentIntent(
  input: StripePaymentIntentInput,
): Promise<StripePaymentIntentResult> {
  const stripe = getStripeClient();
  const currency = input.currency.toLowerCase();
  const breakdown = calculateCustomerPayment(input.creditAmount);
  const decimals = fiatDecimals(currency);
  const amount = Number(toMinorUnits(breakdown.totalCharge, decimals));

  const intent = await stripe.paymentIntents.create({
    amount,
    currency,
    description: input.description ?? `YieldSwarm deposit ${input.reference}`,
    metadata: {
      reference: input.reference,
      userId: input.userId,
      creditAmount: breakdown.creditAmount,
      platformFee: breakdown.platformFee,
      totalCharge: breakdown.totalCharge,
      feeRate: breakdown.feeRate,
      rail: "stripe",
    },
    automatic_payment_methods: { enabled: true },
  });

  if (!intent.client_secret || !intent.id) {
    throw new Error("Stripe did not return a PaymentIntent client secret");
  }

  return {
    paymentIntentId: intent.id,
    clientSecret: intent.client_secret,
    breakdown,
  };
}

/** Verify Stripe webhook signature over the raw request body. */
export function verifyStripeWebhook(
  rawBody: string,
  signature: string | null,
): Stripe.Event {
  const secret = serverEnv.stripe.webhookSecret();
  if (!secret) {
    throw new Error("Stripe webhook secret is not configured");
  }
  if (!signature) {
    throw new Error("Missing Stripe-Signature header");
  }
  const stripe = getStripeClient();
  return stripe.webhooks.constructEvent(rawBody, signature, secret);
}

export function metadataFromStripe(
  metadata: Stripe.Metadata | null | undefined,
): {
  reference?: string;
  userId?: string;
  creditAmount?: string;
  platformFee?: string;
  totalCharge?: string;
} {
  if (!metadata) return {};
  return {
    reference: metadata.reference,
    userId: metadata.userId,
    creditAmount: metadata.creditAmount,
    platformFee: metadata.platformFee,
    totalCharge: metadata.totalCharge,
  };
}
