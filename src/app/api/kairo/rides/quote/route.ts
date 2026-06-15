import { NextResponse } from "next/server";
import { calculateRideFare } from "@/lib/payments/fees";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Calculate customer 1% fee + driver 2× pay breakdown for a ride. */
export async function POST(request: Request) {
  let body: { baseFare?: string; currency?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  if (!body.baseFare) {
    return NextResponse.json({ ok: false, error: "baseFare required" }, { status: 400 });
  }

  try {
    const breakdown = calculateRideFare({
      baseFare: body.baseFare,
      currency: body.currency,
    });
    return NextResponse.json({ ok: true, breakdown });
  } catch (err) {
    const message = err instanceof Error ? err.message : "calculation failed";
    return NextResponse.json({ ok: false, error: message }, { status: 400 });
  }
}
