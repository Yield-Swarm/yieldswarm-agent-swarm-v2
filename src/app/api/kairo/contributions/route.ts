import { NextResponse } from "next/server";
import { kairoStore } from "@/lib/kairo/store";
import { buildDriverEarnings } from "@/lib/kairo/earnings";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Data contribution summary + potential rewards for a driver. */
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const driverId = searchParams.get("driverId");

  if (!driverId) {
    return NextResponse.json({ ok: false, error: "driverId required" }, { status: 400 });
  }

  const db = await kairoStore.read();
  const driver = db.drivers[driverId];
  if (!driver) {
    return NextResponse.json({ ok: false, error: "Driver not found" }, { status: 404 });
  }

  const contribution = Object.values(db.contributions).find((c) => c.driverId === driverId);
  const trips = Object.values(db.trips);
  const telemetry = Object.values(db.telemetry).filter((t) => t.driverId === driverId);
  const earnings = buildDriverEarnings(driverId, contribution, trips);

  return NextResponse.json({
    ok: true,
    driver: {
      id: driver.id,
      evmAddress: driver.evmAddress,
      iotexAddress: driver.iotexAddress,
    },
    contribution: contribution ?? {
      telemetryCount: telemetry.length,
      totalDistanceMiles: telemetry.reduce((s, t) => s + t.payload.distanceMiles, 0),
      estimatedDepinRewards: "0.0000",
      appRevenueShare: "0.00",
    },
    earnings,
    recentTelemetry: telemetry.slice(-10).reverse(),
  });
}
