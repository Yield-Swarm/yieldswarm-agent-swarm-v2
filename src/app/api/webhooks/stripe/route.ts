import { NextResponse } from "next/server";
import type Stripe from "stripe";
import { store } from "@/lib/db/store";
import { findByReference, updateTransactionStatus } from "@/lib/ledger";
import { metadataFromStripe, verifyStripeWebhook } from "@/lib/payments/stripe";
import { nowIso } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Stripe webhook receiver. Verifies signature via constructEvent, then credits
 * the user's balance with the net credit amount (1% fee retained as platform
 * revenue, recorded in transaction metadata).
 */
export async function POST(request: Request) {
  const raw = await request.text();
  const signature = request.headers.get("stripe-signature");

  let event: Stripe.Event;
  try {
    event = verifyStripeWebhook(raw, signature);
  } catch (err) {
    return NextResponse.json(
      { ok: false, error: (err as Error).message },
      { status: 400 },
    );
  }

  const eventId = event.id;
  const already = await store.mutate((db) => {
    if (db.webhookEvents[eventId]) return true;
    db.webhookEvents[eventId] = {
      id: eventId,
      provider: "stripe",
      receivedAt: nowIso(),
    };
    return false;
  });
  if (already) {
    return NextResponse.json({ ok: true, deduped: true });
  }

  try {
    switch (event.type) {
      case "checkout.session.completed":
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case "payment_intent.succeeded":
        await handlePaymentIntentSucceeded(event.data.object as Stripe.PaymentIntent);
        break;
      case "payment_intent.payment_failed":
        await handlePaymentIntentFailed(event.data.object as Stripe.PaymentIntent);
        break;
      default:
        return NextResponse.json({ ok: true, ignored: event.type });
    }
  } catch (err) {
    return NextResponse.json(
      { ok: false, error: (err as Error).message },
      { status: 500 },
    );
  }

  return NextResponse.json({ ok: true });
}

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const meta = metadataFromStripe(session.metadata);
  const reference =
    meta.reference ?? session.client_reference_id ?? undefined;
  if (!reference) return;

  const tx = await findByReference(reference);
  if (!tx || tx.rail !== "stripe") return;
  if (tx.status === "completed") return;

  const paymentIntentId =
    typeof session.payment_intent === "string"
      ? session.payment_intent
      : session.payment_intent?.id;

  await updateTransactionStatus(tx.id, "completed", {
    externalId: paymentIntentId ?? session.id,
    metadata: {
      stripeSessionId: session.id,
      platformFee: meta.platformFee,
      totalCharged: meta.totalCharge,
      settledVia: "checkout.session.completed",
    },
  });
}

async function handlePaymentIntentSucceeded(intent: Stripe.PaymentIntent) {
  const meta = metadataFromStripe(intent.metadata);
  const reference = meta.reference;
  if (!reference) return;

  const tx = await findByReference(reference);
  if (!tx || tx.rail !== "stripe") return;
  if (tx.status === "completed") return;

  await updateTransactionStatus(tx.id, "completed", {
    externalId: intent.id,
    metadata: {
      platformFee: meta.platformFee,
      totalCharged: meta.totalCharge,
      settledVia: "payment_intent.succeeded",
    },
  });
}

async function handlePaymentIntentFailed(intent: Stripe.PaymentIntent) {
  const meta = metadataFromStripe(intent.metadata);
  const reference = meta.reference;
  if (!reference) return;

  const tx = await findByReference(reference);
  if (!tx || tx.rail !== "stripe") return;

  await updateTransactionStatus(tx.id, "failed", {
    externalId: intent.id,
    metadata: {
      stripeFailureMessage: intent.last_payment_error?.message,
      settledVia: "payment_intent.payment_failed",
    },
  });
}
