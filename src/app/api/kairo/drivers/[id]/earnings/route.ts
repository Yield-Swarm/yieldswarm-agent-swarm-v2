import { NextResponse } from "next/server";
import { calculateDriverEarnings } from "@/lib/payments/fees";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Driver earnings breakdown: app revenue + DePIN/crypto rewards + instant cashout. */
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const url = new URL(request.url);
  const appRevenue = url.searchParams.get("appRevenue") ?? "0";
  const depinRewards = url.searchParams.get("depinRewards") ?? "0";
  const cryptoRewards = url.searchParams.get("cryptoRewards") ?? "0";
  const instantCashout = url.searchParams.get("instantCashout") === "1";

  const earnings = calculateDriverEarnings({
    appRevenueUsd: appRevenue,
    depinRewardsUsd: depinRewards,
    cryptoRewardsUsd: cryptoRewards,
    instantCashout,
  });

  return NextResponse.json({
    ok: true,
    driverId: id,
    earnings,
    feeModel: {
      customerPlatformFee: "1%",
      driverPayMultiplier: "2×",
      instantCashoutFee: "1.5%",
    },
  });
}
