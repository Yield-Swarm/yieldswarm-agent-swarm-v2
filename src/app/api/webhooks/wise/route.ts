import { NextResponse } from "next/server";
import { verifyWiseWebhook } from "@/lib/payments/wise";
import { store } from "@/lib/db/store";
import { updateTransactionStatus } from "@/lib/ledger";
import { nowIso } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Wise webhook receiver. Verifies the RSA-SHA256 signature over the raw body,
 * then reconciles transfer/balance events against our recorded transactions.
 */
export async function POST(request: Request) {
  const raw = await request.text();
  const signature =
    request.headers.get("x-signature-sha256") || request.headers.get("x-signature");

  // Wise sends an unsigned test ping during subscription setup; accept it.
  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }
  if (event?.event_type === "ping" || event?.data?.test === true) {
    return NextResponse.json({ ok: true, ping: true });
  }

  if (!verifyWiseWebhook(raw, signature)) {
    return NextResponse.json({ ok: false, error: "Invalid signature" }, { status: 401 });
  }

  const deliveryId = request.headers.get("x-delivery-id") ?? event.subscription_id ?? undefined;
  if (deliveryId) {
    const already = await store.mutate((db) => {
      if (db.webhookEvents[deliveryId]) return true;
      db.webhookEvents[deliveryId] = { id: deliveryId, provider: "wise", receivedAt: nowIso() };
      return false;
    });
    if (already) return NextResponse.json({ ok: true, deduped: true });
  }

  const eventType: string = event.event_type ?? "";
  const resource = event.data?.resource ?? {};
  const resourceId = String(resource.id ?? "");
  const currentState: string = event.data?.current_state ?? "";

  const db = await store.read();
  const wiseTxs = Object.values(db.transactions).filter((t) => t.rail === "wise");
  const tx = wiseTxs.find((t) => t.externalId === resourceId);

  if (eventType.startsWith("transfers#state-change") && tx) {
    if (currentState === "outgoing_payment_sent" || currentState === "funds_converted") {
      await updateTransactionStatus(tx.id, "completed", {
        metadata: { wiseState: currentState },
      });
    } else if (
      currentState === "cancelled" ||
      currentState === "funds_refunded" ||
      currentState === "bounced_back"
    ) {
      await updateTransactionStatus(tx.id, "failed", { metadata: { wiseState: currentState } });
    } else {
      await updateTransactionStatus(tx.id, "processing", { metadata: { wiseState: currentState } });
    }
  } else if (eventType.startsWith("balances#credit") && tx && tx.direction === "deposit") {
    // Inbound deposit settled into our Wise balance.
    await updateTransactionStatus(tx.id, "completed", { metadata: { wiseEvent: eventType } });
  }

  return NextResponse.json({ ok: true, matched: Boolean(tx) });
}
