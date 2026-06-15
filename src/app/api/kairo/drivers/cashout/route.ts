import { NextResponse } from "next/server";
import { z } from "zod";
import { kairoStore } from "@/lib/kairo/store";
import { buildDriverEarnings } from "@/lib/kairo/earnings";
import { computeCashoutFee, netCashoutAmount } from "@/lib/kairo/fees";
import { createTransaction } from "@/lib/ledger";
import { nowIso, reference } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const CashoutSchema = z.object({
  driverId: z.string().uuid(),
  amount: z.string().regex(/^\d+(\.\d{1,2})?$/),
  rail: z.enum(["wise", "square"]).default("wise"),
  instant: z.boolean().default(true),
  /** Bank / payout destination reference (Wise profile id, Square card id, etc.) */
  destinationRef: z.string().optional(),
});

/**
 * Driver instant cashout — routes through Wise or Square withdrawal rails.
 * Deducts instant cashout fee when `instant: true`.
 */
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = CashoutSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: parsed.error.flatten() }, { status: 400 });
  }

  const { driverId, amount, rail, instant, destinationRef } = parsed.data;
  const db = await kairoStore.read();

  if (!db.drivers[driverId]) {
    return NextResponse.json({ ok: false, error: "Driver not found" }, { status: 404 });
  }

  const trips = Object.values(db.trips);
  const earnings = buildDriverEarnings(driverId, undefined, trips);
  const available = parseFloat(earnings.availableCashout);
  const requested = parseFloat(amount);

  if (requested > available) {
    return NextResponse.json(
      { ok: false, error: "Insufficient available balance", available: earnings.availableCashout },
      { status: 400 },
    );
  }

  const fee = computeCashoutFee(amount, instant);
  const net = netCashoutAmount(amount, instant);
  const ref = reference("kairo_cashout");

  const tx = await createTransaction({
    userId: driverId,
    direction: "withdrawal",
    rail,
    amount: net,
    currency: "USD",
    status: instant ? "processing" : "pending",
    reference: ref,
    metadata: {
      source: "kairo",
      grossAmount: amount,
      cashoutFee: fee,
      instant,
      destinationRef,
      driverEvmAddress: db.drivers[driverId]!.evmAddress,
    },
  });

  if (instant) {
    await kairoStore.mutate((store) => {
      let remaining = requested;
      for (const trip of Object.values(store.trips)) {
        if (trip.driverId !== driverId || trip.status !== "completed" || trip.metadata?.cashedOut) {
          continue;
        }
        const pay = parseFloat(trip.driverPay);
        if (remaining <= 0) break;
        trip.metadata = { ...trip.metadata, cashedOut: true, cashoutRef: ref, cashoutAt: nowIso() };
        remaining -= pay;
      }
    });
  }

  return NextResponse.json({
    ok: true,
    cashout: {
      transactionId: tx.id,
      reference: ref,
      rail,
      grossAmount: amount,
      fee,
      netAmount: net,
      instant,
      status: tx.status,
    },
    earnings: buildDriverEarnings(
      driverId,
      Object.values(db.contributions).find((c) => c.driverId === driverId),
      Object.values((await kairoStore.read()).trips),
    ),
  });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const driverId = searchParams.get("driverId");

  if (!driverId) {
    return NextResponse.json({ ok: false, error: "driverId required" }, { status: 400 });
  }

  const db = await kairoStore.read();
  if (!db.drivers[driverId]) {
    return NextResponse.json({ ok: false, error: "Driver not found" }, { status: 404 });
  }

  const contribution = Object.values(db.contributions).find((c) => c.driverId === driverId);
  const trips = Object.values(db.trips);
  const earnings = buildDriverEarnings(driverId, contribution, trips);

  return NextResponse.json({ ok: true, earnings });
}
