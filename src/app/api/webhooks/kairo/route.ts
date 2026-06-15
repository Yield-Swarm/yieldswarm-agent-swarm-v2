import { NextResponse } from "next/server";
import { createHmac, timingSafeEqual } from "node:crypto";
import { serverEnv } from "@/lib/config/env";
import { settleKairoOrder } from "@/lib/payments/kairo-bridge";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function verifySignature(raw: string, signature: string | null): boolean {
  const secret = serverEnv.payments.kairoWebhookSecret();
  if (!secret || !signature) return false;
  const expected = createHmac("sha256", secret).update(raw).digest("hex");
  try {
    return timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
  } catch {
    return false;
  }
}

/**
 * Kairo marketplace webhook — settles customer fare (1% fee) and driver 2× payout.
 */
export async function POST(request: Request) {
  const raw = await request.text();
  const signature = request.headers.get("x-kairo-signature");

  if (!verifySignature(raw, signature)) {
    return NextResponse.json({ ok: false, error: "Invalid signature" }, { status: 401 });
  }

  let body: any;
  try {
    body = JSON.parse(raw);
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const result = await settleKairoOrder({
    orderId: body.orderId,
    customerUserId: body.customerUserId,
    driverUserId: body.driverUserId,
    fareAmount: body.fareAmount,
    currency: body.currency ?? "USD",
    depinRewards: body.depinRewards,
    instantCashout: Boolean(body.instantCashout),
  });

  return NextResponse.json({ ok: true, settlement: result });
}
