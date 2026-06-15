import { NextResponse } from "next/server";
import { calculateKairoFare } from "@/lib/kairo/fees";

export async function POST(req: Request) {
  const body = await req.json().catch(() => ({}));
  const distanceKm = Number(body.distanceKm ?? 0);
  const durationMin = Number(body.durationMin ?? 0);
  if (distanceKm <= 0 && durationMin <= 0) {
    return NextResponse.json({ error: "distanceKm or durationMin required" }, { status: 400 });
  }
  const breakdown = calculateKairoFare({ distanceKm, durationMin });
  return NextResponse.json({
    ...breakdown,
    customerFeePct: 0.01,
    driverMultiplier: 2.0,
    instantCashoutAvailable: true,
  });
}

export async function GET() {
  return NextResponse.json({
    customerFeePct: 0.01,
    driverMultiplier: 2.0,
    depinRewardRate: 0.02,
    description: "Kairo: 1% flat customer fee, 2× driver app pay, DePIN rewards separate",
  });
}
