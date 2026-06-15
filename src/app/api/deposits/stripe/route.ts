import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { railConfigured, serverEnv } from "@/lib/config/env";
import { createTransaction, updateTransactionStatus } from "@/lib/ledger";
import { calculateCustomerPayment } from "@/lib/payments/fees";
import {
  createCheckoutSession,
  createPaymentIntent,
} from "@/lib/payments/stripe";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.discriminatedUnion("mode", [
  z.object({
    mode: z.literal("checkout"),
    amount: z.string().regex(/^\d+(\.\d+)?$/),
    currency: z.string().length(3).default("USD"),
    description: z.string().max(120).optional(),
  }),
  z.object({
    mode: z.literal("payment_intent"),
    amount: z.string().regex(/^\d+(\.\d+)?$/),
    currency: z.string().length(3).default("USD"),
    description: z.string().max(120).optional(),
  }),
]);

/**
 * Create a Stripe payment with 1% platform fee on top of the credit amount.
 * `amount` = balance credited to the user; customer is charged amount + 1%.
 */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  if (!railConfigured("stripe")) return fail("Stripe is not configured", 503);

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const data = body.data;

  const breakdown = calculateCustomerPayment(data.amount);

  const tx = await createTransaction({
    userId: auth.user.id,
    direction: "deposit",
    rail: "stripe",
    amount: breakdown.creditAmount,
    currency: data.currency,
    status: "pending",
    metadata: {
      mode: data.mode,
      platformFee: breakdown.platformFee,
      totalCharge: breakdown.totalCharge,
      feeRate: breakdown.feeRate,
    },
  });

  const customerEmail = auth.user.email.endsWith("@anon.yieldswarm.local")
    ? undefined
    : auth.user.email;

  try {
    if (data.mode === "checkout") {
      const session = await createCheckoutSession({
        creditAmount: breakdown.creditAmount,
        currency: data.currency,
        reference: tx.reference,
        userId: auth.user.id,
        description: data.description,
        customerEmail,
      });

      await updateTransactionStatus(tx.id, "pending", {
        externalId: session.sessionId,
        metadata: {
          checkoutUrl: session.url,
          stripeSessionId: session.sessionId,
        },
      });

      return ok({
        transaction: tx,
        breakdown,
        checkoutUrl: session.url,
        sessionId: session.sessionId,
      });
    }

    const intent = await createPaymentIntent({
      creditAmount: breakdown.creditAmount,
      currency: data.currency,
      reference: tx.reference,
      userId: auth.user.id,
      description: data.description,
    });

    await updateTransactionStatus(tx.id, "pending", {
      externalId: intent.paymentIntentId,
      metadata: { stripePaymentIntentId: intent.paymentIntentId },
    });

    return ok({
      transaction: tx,
      breakdown,
      clientSecret: intent.clientSecret,
      paymentIntentId: intent.paymentIntentId,
    });
  } catch (err) {
    await updateTransactionStatus(tx.id, "failed", {
      metadata: { error: (err as Error).message },
    });
    return fail((err as Error).message || "Stripe payment failed", 502);
  }
}
