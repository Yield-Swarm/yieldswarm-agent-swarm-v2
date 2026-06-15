import { NextResponse } from "next/server";
import { z } from "zod";
import { kairoStore } from "@/lib/kairo/store";
import { computeTripFees } from "@/lib/kairo/fees";
import { nowIso, reference, uuid } from "@/lib/ids";
import { KairoTrip } from "@/lib/kairo/models";
import { upsertContribution } from "@/lib/kairo/mandelbrot";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const CreateTripSchema = z.object({
  customerId: z.string().min(1),
  driverId: z.string().uuid(),
  fareAmount: z.string().regex(/^\d+(\.\d{1,2})?$/),
  currency: z.string().default("USD"),
  metadata: z.record(z.unknown()).optional(),
});

/**
 * Create a Kairo trip with automatic fee calculation:
 * - Customer: 1% flat platform fee on fare
 * - Driver: 2× base pay component
 */
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = CreateTripSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: parsed.error.flatten() }, { status: 400 });
  }

  const { customerId, driverId, fareAmount, currency, metadata } = parsed.data;
  const db = await kairoStore.read();

  if (!db.drivers[driverId]) {
    return NextResponse.json({ ok: false, error: "Driver not found" }, { status: 404 });
  }

  const fees = computeTripFees(fareAmount);
  const now = nowIso();

  const trip: KairoTrip = {
    id: uuid(),
    customerId,
    driverId,
    fareAmount: fees.fareAmount,
    currency: currency.toUpperCase(),
    customerFee: fees.customerFee,
    driverPay: fees.driverPay,
    status: "pending",
    metadata: { ...metadata, ref: reference("trip"), feeBreakdown: fees },
    createdAt: now,
    updatedAt: now,
  };

  await kairoStore.mutate((store) => {
    store.trips[trip.id] = trip;
  });

  return NextResponse.json({
    ok: true,
    trip,
    fees: {
      customerTotal: fees.customerTotal,
      customerFee: fees.customerFee,
      driverPay: fees.driverPay,
      platformRevenue: fees.platformRevenue,
    },
  });
}

const CompleteTripSchema = z.object({
  tripId: z.string().uuid(),
});

export async function PATCH(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = CompleteTripSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: parsed.error.flatten() }, { status: 400 });
  }

  const result = await kairoStore.mutate((store) => {
    const trip = store.trips[parsed.data.tripId];
    if (!trip) return null;
    trip.status = "completed";
    trip.updatedAt = nowIso();

    const existing = Object.values(store.contributions).find((c) => c.driverId === trip.driverId);
    const platformShare = (parseFloat(trip.customerFee) * 0.25).toFixed(2);
    const updated = upsertContribution(existing, trip.driverId, {
      telemetryCount: 0,
      distanceMiles: 0,
      appRevenue: platformShare,
    });
    store.contributions[updated.id] = updated;
    return { trip, contribution: updated };
  });

  if (!result) {
    return NextResponse.json({ ok: false, error: "Trip not found" }, { status: 404 });
  }

  return NextResponse.json({ ok: true, ...result });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const driverId = searchParams.get("driverId");
  const customerId = searchParams.get("customerId");

  const db = await kairoStore.read();
  let trips = Object.values(db.trips);
  if (driverId) trips = trips.filter((t) => t.driverId === driverId);
  if (customerId) trips = trips.filter((t) => t.customerId === customerId);
  trips.sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  return NextResponse.json({ ok: true, trips });
}
