import { NextResponse } from "next/server";
import { buildDriverEarnings, createRide, completeRide, instantCashout, calculateRideEconomics } from "@/lib/kairo/payments";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * GET /api/kairo/earnings?driverId=...&period=2026-06
 * Driver earnings breakdown: app revenue + DePIN rewards.
 */
export async function GET(request: Request) {
  const url = new URL(request.url);
  const driverId = url.searchParams.get("driverId");
  const period = url.searchParams.get("period") ?? new Date().toISOString().slice(0, 7);

  if (!driverId) {
    return NextResponse.json({ error: "driverId required" }, { status: 400 });
  }

  const earnings = await buildDriverEarnings(driverId, period);
  return NextResponse.json({ earnings });
}

/**
 * POST /api/kairo/earnings
 * Actions: create_ride | complete_ride | instant_cashout | quote
 */
export async function POST(request: Request) {
  let body: Record<string, string>;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const action = body.action;

  switch (action) {
    case "quote": {
      const econ = calculateRideEconomics(body.fare ?? "0");
      return NextResponse.json({ economics: econ, feeRate: "1%", driverMultiplier: "2×" });
    }
    case "create_ride": {
      const ride = await createRide(body.customerId, body.driverId, body.fare, body.currency);
      return NextResponse.json({ ride });
    }
    case "complete_ride": {
      const ride = await completeRide(body.rideId);
      if (!ride) return NextResponse.json({ error: "Ride not found" }, { status: 404 });
      return NextResponse.json({ ride });
    }
    case "instant_cashout": {
      const result = await instantCashout(body.driverId, body.amount, body.currency);
      return NextResponse.json(result);
    }
    default:
      return NextResponse.json({ error: `Unknown action: ${action}` }, { status: 400 });
  }
}
