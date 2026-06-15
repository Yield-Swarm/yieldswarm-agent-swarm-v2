import { NextResponse } from "next/server";
import { verifySquareWebhook, squareMoneyToDecimal } from "@/lib/payments/square";
import { store } from "@/lib/db/store";
import { updateTransactionStatus } from "@/lib/ledger";
import { nowIso } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Square webhook receiver. Verifies the HMAC signature over the raw body, then
 * settles the matching deposit when a payment COMPLETES. Idempotent on the
 * Square event id.
 */
export async function POST(request: Request) {
  const raw = await request.text();
  const signature = request.headers.get("x-square-hmacsha256-signature");

  if (!verifySquareWebhook(raw, signature)) {
    return NextResponse.json({ ok: false, error: "Invalid signature" }, { status: 401 });
  }

  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const eventId: string | undefined = event.event_id ?? event.id;
  // Dedupe.
  if (eventId) {
    const already = await store.mutate((db) => {
      if (db.webhookEvents[eventId]) return true;
      db.webhookEvents[eventId] = { id: eventId, provider: "square", receivedAt: nowIso() };
      return false;
    });
    if (already) return NextResponse.json({ ok: true, deduped: true });
  }

  const type: string = event.type ?? "";
  if (!type.startsWith("payment")) {
    return NextResponse.json({ ok: true, ignored: type });
  }

  const payment = event.data?.object?.payment;
  if (!payment) return NextResponse.json({ ok: true, ignored: "no-payment" });

  const tx = await findSquareTransaction(payment);
  if (!tx) return NextResponse.json({ ok: true, unmatched: true });

  const status: string = payment.status ?? "";
  if (status === "COMPLETED" || status === "APPROVED") {
    const money = squareMoneyToDecimal(payment.amount_money);
    await updateTransactionStatus(tx.id, "completed", {
      externalId: payment.id,
      metadata: { squareStatus: status, settledAmount: money?.amount },
    });
  } else if (status === "FAILED" || status === "CANCELED") {
    await updateTransactionStatus(tx.id, "failed", {
      externalId: payment.id,
      metadata: { squareStatus: status },
    });
  } else {
    await updateTransactionStatus(tx.id, "processing", {
      externalId: payment.id,
      metadata: { squareStatus: status },
    });
  }

  return NextResponse.json({ ok: true });
}

async function findSquareTransaction(payment: any) {
  const db = await store.read();
  const all = Object.values(db.transactions).filter((t) => t.rail === "square");

  // 1) by payment id (externalId for direct payments)
  let tx = all.find((t) => t.externalId === payment.id);
  if (tx) return tx;

  // 2) by reference embedded in reference_id or note ("yieldswarm:<ref>")
  const ref =
    payment.reference_id ||
    (typeof payment.note === "string" && payment.note.startsWith("yieldswarm:")
      ? payment.note.split(":")[1]
      : undefined);
  if (ref) {
    tx = all.find((t) => t.reference === ref);
    if (tx) return tx;
  }

  // 3) by order id stored on the payment-link transaction
  if (payment.order_id) {
    tx = all.find((t) => (t.metadata as any)?.orderId === payment.order_id);
    if (tx) return tx;
  }
  return null;
}
